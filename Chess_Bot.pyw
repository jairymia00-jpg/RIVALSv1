"""Local chess practice GUI powered by a user-selected UCI engine (Stockfish)."""
import os
import queue
import re
import subprocess
import threading
import time
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

PIECES = {
    'K': '\u2654', 'Q': '\u2655', 'R': '\u2656', 'B': '\u2657', 'N': '\u2658', 'P': '\u2659',
    'k': '\u265a', 'q': '\u265b', 'r': '\u265c', 'b': '\u265d', 'n': '\u265e', 'p': '\u265f',
}
MOVE = re.compile(r'^([a-h][1-8][a-h][1-8][qrbn]?):\s+\d+\s*$')
FEN = re.compile(r'^Fen:\s*(\S+(?:\s+\S+){5})\s*$')
BEST = re.compile(r'^bestmove\s+(\S+)')


class EngineError(Exception):
    pass


class UCIEngine:
    def __init__(self, path):
        flags = getattr(subprocess, 'CREATE_NO_WINDOW', 0)
        try:
            self.proc = subprocess.Popen(
                [path], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL, text=True, encoding='utf-8', errors='replace',
                bufsize=1, creationflags=flags,
            )
        except (OSError, ValueError) as exc:
            raise EngineError(f'Could not start the engine: {exc}') from exc
        self.lines = queue.Queue()
        threading.Thread(target=self._reader, daemon=True).start()
        self.send('uci')
        self.until(lambda line: line == 'uciok', 15)
        self.send('setoption name Skill Level value 20')
        self.send('setoption name Threads value 2')
        self.send('isready')
        self.until(lambda line: line == 'readyok', 15)

    def _reader(self):
        try:
            for line in self.proc.stdout:
                self.lines.put(line.strip())
        finally:
            self.lines.put(None)

    def send(self, command):
        try:
            self.proc.stdin.write(command + '\n')
            self.proc.stdin.flush()
        except (OSError, ValueError) as exc:
            raise EngineError('The engine stopped responding.') from exc

    def until(self, predicate, seconds):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            try:
                line = self.lines.get(timeout=min(0.25, max(0.01, deadline - time.monotonic())))
            except queue.Empty:
                if self.proc.poll() is not None:
                    raise EngineError('The engine exited unexpectedly.')
                continue
            if line is None:
                raise EngineError('The engine exited unexpectedly.')
            if predicate(line):
                return line
        raise EngineError('The engine timed out.')

    def position(self, moves):
        self.send('position startpos' + (' moves ' + ' '.join(moves) if moves else ''))

    def state(self, moves):
        self.position(moves)
        self.send('d')
        line = self.until(lambda value: FEN.match(value) is not None, 8)
        fen = FEN.match(line).group(1)
        # Stockfish's perft output lists every legal root move.
        self.position(moves)
        self.send('go perft 1')
        legal = []
        def done(value):
            match = MOVE.match(value)
            if match:
                legal.append(match.group(1))
            return value.startswith('Nodes searched:')
        self.until(done, 15)
        return fen, legal

    def best_move(self, moves, milliseconds):
        self.position(moves)
        self.send(f'go movetime {milliseconds}')
        line = self.until(lambda value: BEST.match(value) is not None, milliseconds / 1000 + 20)
        move = BEST.match(line).group(1)
        if move in ('(none)', '0000'):
            return None
        return move

    def new_game(self):
        self.send('ucinewgame')
        self.send('isready')
        self.until(lambda value: value == 'readyok', 15)

    def close(self):
        if self.proc.poll() is None:
            try:
                self.send('quit')
            except EngineError:
                pass
            try:
                self.proc.wait(timeout=0.5)
            except subprocess.TimeoutExpired:
                self.proc.kill()


def parse_board(fen):
    rows = []
    for rank in fen.split()[0].split('/'):
        row = []
        for item in rank:
            row.extend([''] * int(item) if item.isdigit() else [item])
        if len(row) != 8:
            raise EngineError('The engine returned an invalid board.')
        rows.append(row)
    if len(rows) != 8:
        raise EngineError('The engine returned an invalid board.')
    return rows


class ChessBot:
    def __init__(self, root):
        self.root = root
        root.title('Chess Bot | Stockfish practice')
        root.geometry('900x670')
        root.minsize(700, 540)
        root.configure(bg='#11131b')
        self.engine = None
        self.engine_path = ''
        self.messages = queue.Queue()
        self.busy = False
        self.moves = []
        self.legal = []
        self.board = parse_board('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1')
        self.fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'
        self.selected = None
        self.last_move = None
        self.human_side = 'White'
        self.side = tk.StringVar(value='White')
        self.think = tk.IntVar(value=3)
        self.status = tk.StringVar(value='Choose a Stockfish executable to begin.')

        style = ttk.Style()
        try:
            style.theme_use('clam')
        except tk.TclError:
            pass
        style.configure('Night.TButton', background='#a72945', foreground='white', padding=9,
                        borderwidth=0, font=('Segoe UI', 10, 'bold'))
        style.map('Night.TButton', background=[('active', '#d04461'), ('disabled', '#49323b')])
        style.configure('Night.TRadiobutton', background='#1d202c', foreground='#f3f2f5',
                        font=('Segoe UI', 10))
        style.map('Night.TRadiobutton', background=[('active', '#1d202c')])

        outer = tk.Frame(root, bg='#11131b')
        outer.pack(fill='both', expand=True, padx=16, pady=16)
        tk.Label(outer, text='CHESS BOT', bg='#11131b', fg='#fff2f5',
                 font=('Segoe UI', 20, 'bold')).pack(anchor='w')
        tk.Label(outer, text='Play a local game against Stockfish', bg='#11131b', fg='#a9aab6',
                 font=('Segoe UI', 10)).pack(anchor='w', pady=(0, 12))

        body = tk.Frame(outer, bg='#11131b')
        body.pack(fill='both', expand=True)
        self.canvas = tk.Canvas(body, bg='#11131b', highlightthickness=0, width=560, height=560)
        self.canvas.pack(side='left', fill='both', expand=True)
        self.canvas.bind('<Configure>', lambda event: self.draw())
        self.canvas.bind('<Button-1>', self.click)
        panel = tk.Frame(body, bg='#1d202c', width=265, padx=16, pady=16)
        panel.pack(side='right', fill='y', padx=(16, 0))
        panel.pack_propagate(False)
        tk.Label(panel, text='SETUP', bg='#1d202c', fg='#ff6b87',
                 font=('Segoe UI', 11, 'bold')).pack(anchor='w')
        self.pick_button = ttk.Button(panel, text='Choose Stockfish .exe', style='Night.TButton',
                                      command=self.choose_engine)
        self.pick_button.pack(fill='x', pady=(10, 4))
        self.engine_label = tk.Label(panel, text='No engine selected', bg='#1d202c', fg='#a9aab6',
                                     wraplength=225, anchor='w', justify='left', font=('Segoe UI', 9))
        self.engine_label.pack(anchor='w')
        tk.Label(panel, text='PLAY AS', bg='#1d202c', fg='#ff6b87',
                 font=('Segoe UI', 11, 'bold')).pack(anchor='w', pady=(20, 7))
        for choice in ('White', 'Black'):
            ttk.Radiobutton(panel, text=choice, value=choice, variable=self.side,
                            style='Night.TRadiobutton').pack(anchor='w', pady=3)
        tk.Label(panel, text='THINKING TIME', bg='#1d202c', fg='#ff6b87',
                 font=('Segoe UI', 11, 'bold')).pack(anchor='w', pady=(20, 5))
        tk.Scale(panel, from_=1, to=15, variable=self.think, orient='horizontal',
                 bg='#1d202c', fg='white', highlightthickness=0, troughcolor='#11131b',
                 activebackground='#ff6b87', label='Seconds per move').pack(fill='x')
        self.new_button = ttk.Button(panel, text='New game', style='Night.TButton', command=self.new_game)
        self.new_button.pack(fill='x', pady=(18, 7))
        self.undo_button = ttk.Button(panel, text='Undo last turn', style='Night.TButton', command=self.undo)
        self.undo_button.pack(fill='x')
        tk.Label(panel, text='MOVES', bg='#1d202c', fg='#ff6b87',
                 font=('Segoe UI', 11, 'bold')).pack(anchor='w', pady=(20, 6))
        self.move_list = tk.Text(panel, height=9, bg='#141722', fg='#f0edf1',
                                 relief='flat', font=('Consolas', 10), padx=9, pady=9, state='disabled')
        self.move_list.pack(fill='both', expand=True)
        tk.Label(outer, textvariable=self.status, bg='#11131b', fg='#d3c8cf',
                 font=('Segoe UI', 10), anchor='w').pack(fill='x', pady=(10, 0))
        root.protocol('WM_DELETE_WINDOW', self.close)
        self.draw()
        self.update_controls()
        root.after(80, self.poll)

    def run(self, work, success):
        self.busy = True
        self.update_controls()
        def job():
            try:
                result = work()
                self.messages.put((success, result, None))
            except Exception as exc:
                self.messages.put((success, None, exc))
        threading.Thread(target=job, daemon=True).start()

    def poll(self):
        try:
            while True:
                callback, result, error = self.messages.get_nowait()
                self.busy = False
                if error:
                    self.status.set(f'Error: {error}')
                    messagebox.showerror('Chess Bot', str(error), parent=self.root)
                else:
                    callback(result)
                self.update_controls()
        except queue.Empty:
            pass
        self.root.after(80, self.poll)

    def update_controls(self):
        self.pick_button.configure(state='disabled' if self.busy else 'normal')
        self.new_button.configure(state='normal' if self.engine and not self.busy else 'disabled')
        can_undo = self.moves and not (self.human_side == 'Black' and len(self.moves) == 1)
        self.undo_button.configure(state='normal' if self.engine and can_undo and not self.busy else 'disabled')

    def choose_engine(self):
        if self.busy:
            return
        path = filedialog.askopenfilename(title='Select the Stockfish executable',
                                           filetypes=[('Executable', '*.exe'), ('All files', '*.*')])
        if not path:
            return
        old = self.engine
        self.status.set('Starting engine...')
        def work():
            return UCIEngine(path)
        def done(engine):
            self.engine = engine
            self.engine_path = path
            self.engine_label.configure(text=os.path.basename(path))
            if old:
                old.close()
            self.status.set('Engine ready. Press New game.')
        self.run(work, done)

    def new_game(self):
        if not self.engine or self.busy:
            return
        self.human_side = self.side.get()
        self.selected = None
        self.last_move = None
        self.status.set('Starting new game...')
        human_side = self.human_side
        milliseconds = self.think.get() * 1000
        def work():
            self.engine.new_game()
            moves = []
            if human_side == 'Black':
                bot = self.engine.best_move(moves, milliseconds)
                if bot:
                    moves.append(bot)
            fen, legal = self.engine.state(moves)
            return moves, fen, legal
        self.run(work, self.install_state)

    def install_state(self, result):
        self.moves, self.fen, self.legal = result
        self.board = parse_board(self.fen)
        self.last_move = self.moves[-1] if self.moves else None
        self.selected = None
        self.render_moves()
        self.draw()
        if not self.legal:
            self.status.set('Game over: no legal moves remain.')
        else:
            self.status.set('Your move. Click a piece, then its destination.')

    def play(self, move):
        if self.busy or move not in self.legal:
            return
        base_moves = self.moves + [move]
        milliseconds = self.think.get() * 1000
        self.selected = None
        self.status.set('Stockfish is thinking...')
        def work():
            fen, legal = self.engine.state(base_moves)
            if not legal:
                return base_moves, fen, legal
            bot = self.engine.best_move(base_moves, milliseconds)
            if not bot:
                return base_moves, fen, legal
            final = base_moves + [bot]
            fen, legal = self.engine.state(final)
            return final, fen, legal
        self.run(work, self.install_state)
        self.draw()

    def undo(self):
        if not self.engine or self.busy or not self.moves:
            return
        # Undo the bot's response together with the human's preceding move.
        if self.human_side == 'Black' and len(self.moves) == 1:
            return
        previous = self.moves[:-2]
        self.status.set('Undoing...')
        self.run(lambda: (previous, *self.engine.state(previous)), self.install_state)

    def render_moves(self):
        lines = []
        for index in range(0, len(self.moves), 2):
            pair = self.moves[index:index + 2]
            lines.append(f'{index // 2 + 1:>2}.  ' + '   '.join(pair))
        self.move_list.configure(state='normal')
        self.move_list.delete('1.0', 'end')
        self.move_list.insert('end', '\n'.join(lines))
        self.move_list.configure(state='disabled')

    def geometry(self):
        size = max(8, min(self.canvas.winfo_width(), self.canvas.winfo_height()) - 18)
        cell = size / 8
        return (self.canvas.winfo_width() - size) / 2, (self.canvas.winfo_height() - size) / 2, cell

    def square_at(self, col, row):
        if self.human_side == 'White':
            return chr(ord('a') + col) + str(8 - row)
        return chr(ord('h') - col) + str(row + 1)

    def coords(self, square):
        file_no = ord(square[0]) - ord('a')
        rank_no = int(square[1]) - 1
        if self.human_side == 'White':
            return file_no, 7 - rank_no
        return 7 - file_no, rank_no

    def draw(self):
        c = self.canvas
        c.delete('all')
        left, top, cell = self.geometry()
        legal_targets = {move[2:4] for move in self.legal if self.selected and move[:2] == self.selected}
        for row in range(8):
            for col in range(8):
                square = self.square_at(col, row)
                light = (row + col) % 2 == 0
                color = '#ecdfe2' if light else '#6c3344'
                if self.last_move and square in (self.last_move[:2], self.last_move[2:4]):
                    color = '#d8995b' if light else '#9d604d'
                if square == self.selected:
                    color = '#e6ba59'
                x, y = left + col * cell, top + row * cell
                c.create_rectangle(x, y, x + cell, y + cell, fill=color, outline=color)
                board_row = 8 - int(square[1])
                board_col = ord(square[0]) - ord('a')
                piece = self.board[board_row][board_col]
                if piece:
                    c.create_text(x + cell / 2, y + cell / 2,
                                  text=PIECES[piece], fill='#fffaf5' if piece.isupper() else '#171620',
                                  font=('Segoe UI Symbol', max(16, int(cell * 0.69))))
                if square in legal_targets:
                    c.create_oval(x + cell * .41, y + cell * .41, x + cell * .59, y + cell * .59,
                                  fill='#ff405e', outline='#28151b')
                if col == 0:
                    c.create_text(x + 5, y + 5, text=square[1], anchor='nw',
                                  fill='#3e2030' if light else '#f8e4e9', font=('Segoe UI', 9, 'bold'))
                if row == 7:
                    c.create_text(x + cell - 5, y + cell - 5, text=square[0], anchor='se',
                                  fill='#3e2030' if light else '#f8e4e9', font=('Segoe UI', 9, 'bold'))

    def click(self, event):
        if not self.engine or self.busy or not self.legal:
            return
        left, top, cell = self.geometry()
        col, row = int((event.x - left) // cell), int((event.y - top) // cell)
        if not 0 <= col < 8 or not 0 <= row < 8:
            return
        square = self.square_at(col, row)
        if self.selected:
            options = [move for move in self.legal if move[:2] == self.selected and move[2:4] == square]
            if options:
                self.play(next((move for move in options if move.endswith('q')), options[0]))
                return
        if any(move.startswith(square) for move in self.legal):
            self.selected = square
        else:
            self.selected = None
        self.draw()

    def close(self):
        if self.engine:
            self.engine.close()
        self.root.destroy()


if __name__ == '__main__':
    window = tk.Tk()
    ChessBot(window)
    window.mainloop()

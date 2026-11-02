const board = document.querySelector('.sudoku');
const controls = document.querySelectorAll('[data-rule]');
if (board && controls.length) {
  const caption = document.querySelector('.demo-caption');
  const english = document.documentElement.lang === 'en';
  const explanations = english
    ? { row: 'A row: each digit from 1 to 9 appears once.', column: 'A column: each digit from 1 to 9 appears once.', box: 'A 3 × 3 box: each digit from 1 to 9 appears once.' }
    : { row: '同一行，1—9 各出现一次。', column: '同一列，1—9 各出现一次。', box: '同一宫，1—9 各出现一次。' };
  controls.forEach(button => button.addEventListener('click', () => {
    const rule = button.dataset.rule;
    controls.forEach(control => control.setAttribute('aria-pressed', String(control === button)));
    board.querySelectorAll('.cell').forEach((cell, index) => {
      const row = Math.floor(index / 9), column = index % 9;
      cell.classList.toggle('mark', rule === 'row' ? row === 4 : rule === 'column' ? column === 4 : row >= 3 && row <= 5 && column >= 3 && column <= 5);
    });
    caption.textContent = explanations[rule];
  }));
}

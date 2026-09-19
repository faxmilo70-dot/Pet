javascript
const API_URL = 'http://localhost:5000/api';

const form  = document.getElementById('task-form');
const input = document.getElementById('task-input');
const list  = document.getElementById('task-list');

async function loadTasks() {
  const res = await fetch(`${API_URL}/tasks`);
  const tasks = await res.json();
  list.innerHTML = '';
  tasks.forEach(task => {
    const li = document.createElement('li');
    if (task.done) li.classList.add('done');

    const cb = document.createElement('input');
    cb.type = 'checkbox';
    cb.checked = !!task.done;
    cb.addEventListener('change', () => toggleTask(task.id, cb.checked));

    const span = document.createElement('span');
    span.textContent = task.title;

    const del = document.createElement('button');
    del.textContent = '✕';
    del.addEventListener('click', () => deleteTask(task.id));

    li.append(cb, span, del);
    list.appendChild(li);
  });
}

async function createTask(title) {
  await fetch(`${API_URL}/tasks`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ title })
  });
  loadTasks();
}

async function toggleTask(id, done) {
  await fetch(`${API_URL}/tasks/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ done })
  });
  loadTasks();
}

async function deleteTask(id) {
  await fetch(`${API_URL}/tasks/${id}`, { method: 'DELETE' });
  loadTasks();
}

form.addEventListener('submit', e => {
  e.preventDefault();
  const title = input.value.trim();
  if (!title) return;
  createTask(title);
  input.value = '';
});

loadTasks();
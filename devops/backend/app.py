from flask import Flask, jsonify, request
from flask_cors import CORS
from dotenv import load_dotenv
import psycopg2
import psycopg2.extras
import os

load_dotenv()

app = Flask(__name__)
CORS(app)

DB_URL = os.getenv('DATABASE_URL', 'postgresql://petuser:secret@localhost:5432/petapp')

def get_db():
    conn = psycopg2.connect(DB_URL)
    conn.autocommit = False
    return conn

def init_db():
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute('''
                CREATE TABLE IF NOT EXISTS tasks (
                    id SERIAL PRIMARY KEY,
                    title TEXT NOT NULL,
                    done BOOLEAN DEFAULT FALSE,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
        conn.commit()

@app.route('/api/tasks', methods=['GET'])
def list_tasks():
    with get_db() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute('SELECT * FROM tasks ORDER BY id DESC')
            return jsonify([dict(r) for r in cur.fetchall()])

@app.route('/api/tasks', methods=['POST'])
def create_task():
    data = request.get_json() or {}
    title = (data.get('title') or '').strip()
    if not title:
        return jsonify({'error': 'title is required'}), 400
    with get_db() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute('INSERT INTO tasks (title) VALUES (%s) RETURNING *', (title,))
            row = cur.fetchone()
        conn.commit()
        return jsonify(dict(row)), 201

@app.route('/api/tasks/<int:task_id>', methods=['PUT'])
def update_task(task_id):
    data = request.get_json() or {}
    done = bool(data.get('done'))
    with get_db() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute('UPDATE tasks SET done = %s WHERE id = %s RETURNING *', (done, task_id))
            row = cur.fetchone()
        conn.commit()
        if row is None:
            return jsonify({'error': 'not found'}), 404
        return jsonify(dict(row))

@app.route('/api/tasks/<int:task_id>', methods=['DELETE'])
def delete_task(task_id):
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute('DELETE FROM tasks WHERE id = %s', (task_id,))
        conn.commit()
    return '', 204

if __name__ == '__main__':
    init_db()
    app.run(host='0.0.0.0', port=5000, debug=True)

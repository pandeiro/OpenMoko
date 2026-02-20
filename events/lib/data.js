import { readFile, writeFile, mkdir, readdir, unlink, stat } from 'node:fs/promises';
import { join, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { randomUUID } from 'node:crypto';

const DATA_DIR = process.env.DATA_DIR || '/data';

/**
 * Ensure the data directory structure exists and seed empty files if missing.
 */
export async function ensureDataDir() {
    await mkdir(join(DATA_DIR, 'failures'), { recursive: true });

    const seeds = {
        'repos.json': '{}',
        'push_subscriptions.json': '[]',
        'active_session.json': 'null',
    };

    for (const [file, content] of Object.entries(seeds)) {
        const path = join(DATA_DIR, file);
        try {
            await stat(path);
        } catch {
            await writeFile(path, content, 'utf-8');
        }
    }

    // Prune failure records older than 48 hours
    await pruneFailures();
}

/**
 * Read and parse a JSON file from the data directory.
 */
export async function readJSON(relativePath) {
    const path = join(DATA_DIR, relativePath);
    try {
        const raw = await readFile(path, 'utf-8');
        return JSON.parse(raw);
    } catch {
        return null;
    }
}

/**
 * Atomically write a JSON file to the data directory.
 * Writes to a temp file first, then renames for crash safety.
 */
export async function writeJSON(relativePath, data) {
    const path = join(DATA_DIR, relativePath);
    await mkdir(dirname(path), { recursive: true });

    const tmp = join(tmpdir(), `openmoko-${randomUUID()}.json`);
    await writeFile(tmp, JSON.stringify(data, null, 2), 'utf-8');

    // Rename is atomic on the same filesystem; tmp may be different,
    // so we copy + unlink as fallback.
    try {
        const { rename } = await import('node:fs/promises');
        await rename(tmp, path);
    } catch {
        await writeFile(path, JSON.stringify(data, null, 2), 'utf-8');
        await unlink(tmp).catch(() => { });
    }
}

/**
 * Prune failure records older than 48 hours.
 */
async function pruneFailures() {
    const failuresDir = join(DATA_DIR, 'failures');
    const cutoff = Date.now() - 48 * 60 * 60 * 1000;

    try {
        const files = await readdir(failuresDir);
        for (const file of files) {
            if (!file.endsWith('.json')) continue;
            const path = join(failuresDir, file);
            try {
                const raw = await readFile(path, 'utf-8');
                const record = JSON.parse(raw);
                if (record.capturedAt && new Date(record.capturedAt).getTime() < cutoff) {
                    await unlink(path);
                    console.log(`Pruned stale failure record: ${file}`);
                }
            } catch {
                // Skip malformed files
            }
        }
    } catch {
        // failures dir may be empty, that's fine
    }
}

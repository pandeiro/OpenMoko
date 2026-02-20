/**
 * GitHub API helper — PAT-authenticated fetch wrapper.
 */

const GITHUB_API = 'https://api.github.com';

function headers() {
    const h = {
        Accept: 'application/vnd.github+json',
        'User-Agent': 'openmoko-events',
        'X-GitHub-Api-Version': '2022-11-28',
    };
    if (process.env.GITHUB_PAT) {
        h.Authorization = `Bearer ${process.env.GITHUB_PAT}`;
    }
    return h;
}

/**
 * List all repos for the authenticated user.
 * Returns array of { name, description, defaultBranch, lastPushed, private, cloneUrl, sshUrl }.
 */
export async function listRepos() {
    const repos = [];
    let page = 1;
    const perPage = 100;

    while (true) {
        const res = await fetch(
            `${GITHUB_API}/user/repos?per_page=${perPage}&page=${page}&sort=pushed&direction=desc`,
            { headers: headers() }
        );

        if (!res.ok) {
            const body = await res.text();
            throw new Error(`GitHub API error ${res.status}: ${body}`);
        }

        const data = await res.json();
        if (data.length === 0) break;

        for (const r of data) {
            repos.push({
                name: r.name,
                fullName: r.full_name,
                description: r.description || '',
                defaultBranch: r.default_branch,
                lastPushed: r.pushed_at,
                private: r.private,
                cloneUrl: r.clone_url,
                sshUrl: r.ssh_url,
            });
        }

        if (data.length < perPage) break;
        page++;
    }

    return repos;
}

/**
 * Fetch the logs for a specific failing step in a workflow run.
 * Returns the last `tailLines` lines of the step log.
 */
export async function getWorkflowFailureLogs(owner, repo, runId, tailLines = 50) {
    // 1. Get jobs for the run
    const jobsRes = await fetch(
        `${GITHUB_API}/repos/${owner}/${repo}/actions/runs/${runId}/jobs`,
        { headers: headers() }
    );

    if (!jobsRes.ok) {
        throw new Error(`Failed to fetch jobs: ${jobsRes.status}`);
    }

    const { jobs } = await jobsRes.json();
    const failedJob = jobs.find((j) => j.conclusion === 'failure');
    if (!failedJob) return null;

    const failedStep = failedJob.steps?.find((s) => s.conclusion === 'failure');

    // 2. Download logs for the job
    const logsRes = await fetch(
        `${GITHUB_API}/repos/${owner}/${repo}/actions/jobs/${failedJob.id}/logs`,
        { headers: headers(), redirect: 'follow' }
    );

    if (!logsRes.ok) {
        throw new Error(`Failed to fetch logs: ${logsRes.status}`);
    }

    const logText = await logsRes.text();
    const lines = logText.split('\n');
    const tail = lines.slice(-tailLines).join('\n');

    return {
        failingJob: failedJob.name,
        failingStep: failedStep?.name || 'unknown',
        logTail: tail,
    };
}

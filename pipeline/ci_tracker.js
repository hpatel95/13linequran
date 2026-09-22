const { execSync } = require('child_process');

function getToken() {
  try {
    const out = execSync('git credential fill', {
      input: 'protocol=https\nhost=github.com\n',
      stdio: ['pipe', 'pipe', 'ignore'],
    }).toString();
    const token = out.match(/password=(.+)/)?.[1]?.trim();
    if (token) return token;
  } catch (e) {}
  return process.env.GITHUB_TOKEN || process.env.GH_TOKEN || null;
}

const token = getToken();
if (!token) {
  console.error('Error: Could not obtain GitHub token.');
  process.exit(1);
}

const headers = {
  Authorization: `token ${token}`,
  'User-Agent': 'CI-Tracker-Node',
  Accept: 'application/vnd.github.v3+json',
};

function getRepo() {
  if (process.env.GITHUB_REPOSITORY) return process.env.GITHUB_REPOSITORY;
  try {
    const remote = execSync('git config --get remote.origin.url', { stdio: ['pipe', 'pipe', 'ignore'] }).toString().trim();
    const match = remote.match(/github\.com[:\/]([^\/]+\/[^\/\.]+)/);
    if (match) return match[1].replace(/\.git$/, '');
  } catch (e) {}
  throw new Error('Unable to determine repository name from GITHUB_REPOSITORY or git remote origin');
}

const repo = getRepo();

async function api(path) {
  const url = path.startsWith('http') ? path : `https://api.github.com/repos/${repo}${path}`;
  const res = await fetch(url, { headers });
  if (!res.ok) {
    throw new Error(`API ${res.status} ${res.statusText}: ${await res.text()}`);
  }
  return res.json();
}

async function getLatestRuns(count = 5) {
  const data = await api(`/actions/runs?per_page=${count}`);
  return data.workflow_runs;
}

async function getRunJobs(runId) {
  const data = await api(`/actions/runs/${runId}/jobs`);
  return data.jobs;
}

async function showStatus() {
  const runs = await getLatestRuns(3);
  console.log('\n--- Recent GitHub Actions Runs ---');
  for (const r of runs) {
    console.log(`Run #${r.id} | SHA: ${r.head_sha.slice(0, 7)} | Commit: "${r.head_commit?.message?.split('\n')[0]}"`);
    console.log(`  Status: ${r.status} | Conclusion: ${r.conclusion || 'pending'} | URL: ${r.html_url}`);
    try {
      const jobs = await getRunJobs(r.id);
      for (const j of jobs) {
        console.log(`    Job: [${j.name}] - Status: ${j.status}, Conclusion: ${j.conclusion || 'pending'}`);
        if (j.conclusion === 'failure') {
          for (const s of j.steps) {
            if (s.conclusion === 'failure') {
              console.log(`      FAILED STEP: "${s.name}" (step #${s.number})`);
            }
          }
        }
      }
    } catch (e) {
      console.log(`    Could not fetch jobs: ${e.message}`);
    }
  }
  console.log('----------------------------------\n');
}

async function watchRun(targetSha) {
  console.log(`Waiting/watching for run with SHA starting with ${targetSha}...`);
  let runId = null;
  while (!runId) {
    const runs = await getLatestRuns(5);
    const match = runs.find(r => r.head_sha.startsWith(targetSha));
    if (match) {
      runId = match.id;
      console.log(`Found run #${runId} for SHA ${targetSha}: ${match.html_url}`);
      break;
    }
    console.log(`Run not yet queued for ${targetSha}. Retrying in 5s...`);
    await new Promise(r => setTimeout(r, 5000));
  }

  while (true) {
    const r = await api(`/actions/runs/${runId}`);
    const jobs = await getRunJobs(runId);
    const timeStr = new Date().toLocaleTimeString();
    console.log(`[${timeStr}] Run #${runId}: status=${r.status}, conclusion=${r.conclusion || 'pending'}`);
    for (const j of jobs) {
      console.log(`   [${j.name}]: ${j.status} / ${j.conclusion || 'in_progress'}`);
    }

    if (r.status === 'completed') {
      console.log(`\nRun finished with conclusion: ${r.conclusion}`);
      for (const j of jobs) {
        console.log(`\nJob "${j.name}": ${j.conclusion}`);
        for (const s of j.steps) {
          console.log(`  Step ${s.number}: ${s.name} -> ${s.conclusion || s.status}`);
          if (s.conclusion === 'failure') {
            console.log(`    *** FAILED STEP: ${s.name} ***`);
          }
        }
      }
      return r.conclusion === 'success';
    }

    await new Promise(res => setTimeout(res, 15000));
  }
}

async function main() {
  const arg = process.argv[2];
  if (arg === '--watch') {
    const sha = process.argv[3] || execSync('git rev-parse HEAD').toString().trim().slice(0, 7);
    const success = await watchRun(sha);
    process.exit(success ? 0 : 1);
  } else {
    await showStatus();
  }
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});

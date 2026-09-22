const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

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
  'User-Agent': 'CI-Downloader-Node',
  Accept: 'application/vnd.github.v3+json',
};

async function downloadVerificationArtifact(runId, outDir) {
  const listUrl = `https://api.github.com/repos/hpatel95/13linequran/actions/runs/${runId}/artifacts`;
  const res = await fetch(listUrl, { headers });
  if (!res.ok) throw new Error(`Failed to list artifacts: ${res.statusText}`);
  const data = await res.json();
  const artifact = data.artifacts.find(a => a.name === 'Quran13Line-verification');
  if (!artifact) {
    console.error('Quran13Line-verification artifact not found. Available:', data.artifacts.map(a => a.name));
    return false;
  }

  console.log(`Downloading artifact #${artifact.id} (${artifact.name}, ${(artifact.size_in_bytes / 1024 / 1024).toFixed(1)} MB)...`);
  const downloadUrl = artifact.archive_download_url;
  const zipRes = await fetch(downloadUrl, { headers, redirect: 'follow' });
  if (!zipRes.ok) throw new Error(`Failed to download zip: ${zipRes.statusText}`);

  const buffer = Buffer.from(await zipRes.arrayBuffer());
  const zipPath = path.join(outDir, 'verification.zip');
  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(zipPath, buffer);
  console.log(`Saved zip to ${zipPath} (${buffer.length} bytes)`);

  // Unzip using tar or powershell Expand-Archive
  try {
    execSync(`tar -xf "${zipPath}" -C "${outDir}"`, { stdio: 'inherit' });
    console.log(`Extracted artifact to ${outDir}`);
  } catch (e) {
    execSync(`powershell -Command "Expand-Archive -Path '${zipPath}' -DestinationPath '${outDir}' -Force"`, { stdio: 'inherit' });
    console.log(`Extracted artifact via PowerShell to ${outDir}`);
  }
  return true;
}

async function main() {
  const runId = process.argv[2] || '35682934637';
  const outDir = path.resolve(__dirname, '../scratch/ci_artifacts_vector');
  await downloadVerificationArtifact(runId, outDir);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});

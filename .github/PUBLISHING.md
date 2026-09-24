# Publishing tcs.azure to the PowerShell Gallery

Releases of `tcs.azure` are tagged and published by GitHub Actions. The workflows in this
repository call the shared workflows in
[ntatschner/tcs-shared-workflows](https://github.com/ntatschner/tcs-shared-workflows).

| Workflow file | Name in the Actions tab | What it does |
| --- | --- | --- |
| `.github/workflows/ci-validate.yml` | CI Validate | Manifest, import and smoke tests, PSScriptAnalyzer, Pester on Windows PowerShell 5.1 and PowerShell 7 (Windows, Ubuntu, macOS). |
| `.github/workflows/create-version-tag.yml` | Create Version Tag | Creates the tag `v<ModuleVersion>` when the manifest version is greater than the latest tag. |
| `.github/workflows/generate-docs.yml` | Generate PowerShell Documentation | Generates the markdown help in `docs/` and the external help with PlatyPS, and commits them to `main`. |
| `.github/workflows/publish-to-psgallery.yml` | Publish to PSGallery | Validates the module, publishes it to the PowerShell Gallery and creates a GitHub release. |

## Prerequisites

### PowerShell Gallery API key

1. Sign in to the [PowerShell Gallery](https://www.powershellgallery.com/) and open **API Keys**.
2. Create a key with the **Push new packages and package versions** scope and a glob pattern that
   covers `tcs.azure` (for example `tcs.azure` or `tcs.*`).
3. Copy the key.

### Repository secret

1. In the repository, go to **Settings** > **Secrets and variables** > **Actions**.
2. Add a repository secret named `PSGALLERY_API_KEY` with the API key as its value.

No other secret is needed; the tag and docs workflows use the built-in `GITHUB_TOKEN`.

## Releasing a new version

1. Make the changes in a pull request. CI Validate must pass.
2. In the same pull request, raise `ModuleVersion` in `modules/tcs.azure/tcs.azure.psd1`
   (semantic versioning) and add a section for the new version to `CHANGELOG.md`.
3. Merge to `main`. When the manifest changes on `main`, or after CI Validate succeeds on `main`,
   **Create Version Tag** compares `ModuleVersion` with the highest `v*` tag and, if the manifest
   version is greater, creates and pushes the tag `v<version>` (for example `v0.2.0`). If the
   version is not greater, no tag is created.
4. **Start the publish manually.** A tag pushed by a workflow with the `GITHUB_TOKEN` does not
   trigger other workflows, so the `push: tags` trigger of Publish to PSGallery does not fire for
   tags created by Create Version Tag. Go to **Actions** > **Publish to PSGallery** >
   **Run workflow**, choose the tag `v<version>` (not `main`) in **Use workflow from**, and run it.
   Running it on the tag publishes the tagged commit and creates the GitHub release `v<version>`.
5. Check the run, then check the module on the PowerShell Gallery.

To publish automatically instead, the owner can give Create Version Tag a personal access token
(or GitHub App token) with `contents: write`, stored as a secret and passed as `repo-token` in
`create-version-tag.yml`. Tags pushed with that token trigger Publish to PSGallery on their own.

A tag pushed by a person (`git tag v0.2.0` then `git push origin v0.2.0`) also triggers the publish
workflow, but let Create Version Tag create tags so the tag always matches the manifest.

## What the publish workflow does

Validation (Windows runner):

- `Test-ModuleManifest` on the manifest.
- PSScriptAnalyzer over the module folder; errors fail the run (warnings are only listed).
- Installs the RequiredModules (`tcs.core`) and imports the module.
- Checks whether this version is already on the PowerShell Gallery. If it is, publishing is
  skipped unless **Force publish** was ticked when the workflow was run manually.

Publishing:

- Publishes `modules/tcs.azure` with `Publish-PSResource` (falls back to `Publish-Module`).
- Creates a GitHub release `v<version>` when the run is on a `v*` tag.

The Microsoft Entra PowerShell module is not needed to publish or to generate the docs: it is not a
RequiredModule, and tcs.azure imports without it.

## Troubleshooting

- **API key invalid or 403**: check the secret is named exactly `PSGALLERY_API_KEY`, the key has not
  expired, has push rights and its glob covers `tcs.azure`.
- **Version already exists**: raise `ModuleVersion` in the manifest. Force publish is only for
  re-running a failed publish of the same version.
- **No tag was created**: the manifest version must be greater than the highest existing `v*` tag,
  and CI Validate must have succeeded.
- **Publish did not start after the tag was created**: expected with `GITHUB_TOKEN`; run Publish to
  PSGallery manually on the tag as described above.
- **Import fails in validation**: check that `tcs.core` 0.3.0 or later is on the PowerShell Gallery
  and that the module imports locally with `Import-Module ./modules/tcs.azure/tcs.azure.psd1`.

## Security

- Never commit API keys; keep them in repository secrets.
- Rotate the PowerShell Gallery key before it expires and scope it to the modules it publishes.

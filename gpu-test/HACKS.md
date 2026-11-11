# Test-only workarounds

Everything listed here exists only to build the GPU test images. None of it
belongs into a pull request. The PR branches (`amd-kfd`, `nvidia-sysext`,
`amdgpu-userptr-log`, `yellow-v3d`, `aarch64-gpu` and the branches in the
other repositories) stay free of it.

| Workaround | Where | Why | Upstream replacement |
| --- | --- | --- | --- |
| Supervisor test image tagged as `ghcr.io/home-assistant/amd64-hassio-supervisor:latest` in the data partition | `make-variant.sh` | HAOS starts only this image name | Released Supervisor with the GPU changes |
| `homeassistant.json` with fork image, `override_image: true` and the Core version | `make-variant.sh` | Skip the landing page and stay on the fork image | Released Core |
| Core image tag taken from the `io.hass.version` label, not `__version__` | workflow, job `core` | The Supervisor looks for the tag of the label; dev builds differ | Released Core |
| Frontend pin in `frontend/manifest.json` and `package_constraints.txt` set to the bundled build | `Dockerfile.core` | Core otherwise installs the pinned frontend from PyPI and replaces the GPU frontend | Released frontend plus regular pin bump in Core |
| English translations generated in the image (`script.translations develop`) | `Dockerfile.core` | `translations/en.json` is not in git | Translations built by the Core release process |
| Core overlay on `ghcr.io/home-assistant/<machine>-homeassistant:dev` | `Dockerfile.core` | No full Core build in the workflow | Released Core |
| OS Agent built from the fork with `-X main.version=1.15.0` | workflow, job `os` | The Supervisor connects to the GPU interface only from OS Agent 1.15.0 | OS Agent release with the GPU interface (version to be agreed) |
| Supervisor branch `gpu-test-combined-v2` merges `video-gpu-access`, `gpu-info` and `os-variants` | supervisor fork | One image with all features | Separate PRs |
| Self-signed RAUC key when no repository secrets exist | workflow, job `prepare` | Fork without the release key | Official signing in the release workflow |

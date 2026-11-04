# Publishing this portfolio repository

## Upload through GitHub's website

1. Sign into the GitHub account you control.
2. Visit <https://github.com/new>.
3. Create a new repository named `cluster` (public if you intend to show it to recruiters). Do **not** add an initial README or license when creating it.
4. Extract the provided ZIP on your computer.
5. In the empty repository, select **uploading an existing file** and upload the extracted files and folders, including `.github` and `.gitignore`.
6. Commit the uploaded files to `main` and inspect the rendered README.

Ensure you upload the **contents** of the `cluster/` directory at the repository root, not a single ZIP file, so GitHub renders the README and code.

## Using Git and GitHub CLI instead

From inside the extracted `cluster/` directory:

```bash
git init -b main
git add .
git commit -m "Initial portfolio documentation and reference implementation"
gh repo create cluster --public --source=. --remote=origin --push
```

Do not use those commands to overwrite an existing repository; check the repository name and owner first.

## Before enabling a public repository

- Inspect all files for secrets or confidential material.
- Do not add real network inventory, GGUF binaries, SSH keys, or private logs.
- Add a license only if you want to grant other people rights to reuse the code.
- Do not claim the sample API is the original deployment or that the archival measurements were reproduced.

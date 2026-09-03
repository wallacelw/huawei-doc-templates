# Documents

This folder is the default location for new Huawei Cloud documents created
with the templates in this project. See the [root README](../README.md) for
setup and [SKILL.md](../templates/guide/SKILL.md) for the full command
reference.

## Creating a new document

**Easiest way — use the scaffolder:**

```bash
./new-doc.sh                 # interactive — picks a template and scaffolds the folder
./new-doc.sh --type guide --title "ECS Setup" --lang en --name ecs-setup
./new-doc.sh --list          # list available templates
```

This creates a self-contained subfolder here with the right skeleton files.

**Or use a skill directly:**

1. Run the skill for the template you want to use:
   ```
   /skill huawei-template-guide
   ```
2. The skill will create a subfolder here, e.g. `documents/my-guide/`,
   with all necessary files (`src/main.tex`, `src/.latexmkrc`, `assets/`).
3. Compile from the repo root:
   ```
   make project DIR=documents/my-guide
   ```
   Or from inside the project folder:
   ```
   cd documents/my-guide/src
   latexmk main.tex
   ```

## Structure

Each document is self-contained in its own subfolder:

```
documents/
+-- my-guide/
    +-- src/
    |   +-- main.tex       # the document
    |   +-- .latexmkrc     # XeLaTeX + TEXINPUTS → templates/_base/ + templates/guide/
    +-- assets/            # project-specific images
```

The `documents/` folder is gitignored by default (only `documents/README.md`
is tracked). To force-track a document in version control, use
`git add -f <path>`.

**⚠ Data loss risk:** Documents in this folder are local-only. If your machine
is lost or reinstalled, these documents will be gone. To protect important work:
- Push to a private Git remote: `git remote add private <url> && git push -f private`
- Or force-track: `git add -f documents/my-guide/`

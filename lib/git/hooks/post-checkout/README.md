# Branch specific `.gitignore`

This `post-checkout` hook will copy `.gitignore.branch_name in place` of `.git/info/exclude` each time with `git checkout branch_name`.

## Setup

1. Create new `.gitignore` files for each branch and name it : `.gitignore.branch_name`
2. In your git repo, go to `.git/hooks/` and copy `post-checkout` file there.
3. Make sure permissions are: `chmod +x post-checkout` and `chmod 755 post-checkout`
4. Just go to the branch you want and type `git status`: **TADAAA** !

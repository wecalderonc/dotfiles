#!/bin/zsh
set -e

echo "Type in your first and last name (no accent or special characters - e.g. 'ç'): "
read full_name

echo "Type in your email address (the one used for your GitHub account): "
read email

git config --global user.email "$email"
git config --global user.name "$full_name"

# Dual-account support: pick which GitHub user / SSH host this machine uses for these dotfiles
echo ""
echo "Which GitHub account owns these dotfiles?"
echo "  1) personal (wecalderonc)  -> git@github.com-personal"
echo "  2) work     (willcalderonc) -> git@github.com-work"
echo -n "Choose [1/2] (default: 1): "
read account_choice

case "${account_choice:-1}" in
  2)
    github_user="willcalderonc"
    ssh_host="github.com-work"
    ssh_key="$HOME/.ssh/id_ed25519_work"
    ;;
  *)
    github_user="wecalderonc"
    ssh_host="github.com-personal"
    ssh_key="$HOME/.ssh/id_ed25519_personal"
    ;;
esac

if [ ! -f "$ssh_key" ]; then
  echo "ERROR: SSH key not found at $ssh_key"
  echo "Create it first, then add the .pub key to https://github.com/settings/keys"
  exit 1
fi

# Make sure the chosen key is loaded (macOS keychain)
if [[ "$(uname)" == "Darwin" ]]; then
  ssh-add --apple-use-keychain "$ssh_key" 2>/dev/null || ssh-add "$ssh_key" 2>/dev/null || true
fi

echo "-----> Checking SSH auth as $github_user via $ssh_host..."
ssh_output="$(ssh -T "git@$ssh_host" 2>&1 || true)"
echo "$ssh_output"
if ! echo "$ssh_output" | grep -q "Hi $github_user!"; then
  echo "ERROR: GitHub authenticated as the wrong user (expected $github_user)."
  echo "Fix ~/.ssh/config host '$ssh_host' / your SSH keys, then re-run."
  exit 1
fi

# Point origin at the account-specific SSH host (avoids work key pushing to personal repos)
origin_url="git@${ssh_host}:${github_user}/dotfiles.git"
if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$origin_url"
else
  git remote add origin "$origin_url"
fi
echo "-----> origin -> $origin_url"

# Commit identity only when there are real changes
git add .
if git diff --cached --quiet; then
  echo "-----> Nothing new to commit"
else
  git commit --message "My identity for @lewagon in the gitconfig"
fi

git push -u origin master

# Upstream may already exist on re-runs
if git remote get-url upstream >/dev/null 2>&1; then
  git remote set-url upstream git@github.com:lewagon/dotfiles.git
else
  git remote add upstream git@github.com:lewagon/dotfiles.git
fi

echo "👌 Awesome, all set for @$github_user."

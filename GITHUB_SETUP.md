# GitHub アップロード手順

このプロジェクトをGitHubにアップロードするための手順です。

## 1. GitHubでリポジトリを作成

1. GitHubにログインします: https://github.com
2. 右上の「+」ボタンをクリック → 「New repository」を選択
3. リポジトリ名を入力: `modified-DeGAUSS-EVproject`
4. 説明（オプション）: "Modified DeGAUSS pipeline for environmental exposure assessment"
5. **Public** または **Private** を選択
6. **「Initialize this repository with a README」のチェックを外す**（既にREADME.mdがあります）
7. 「Create repository」をクリック

## 2. リモートリポジトリを追加してプッシュ

GitHubでリポジトリを作成した後、以下のコマンドを実行してください：

```powershell
cd "C:\Users\shiroa1\OneDrive - VUMC\modified_degauss"

# 既存のリモートがある場合は削除
git remote remove origin

# リモートリポジトリを追加（YOUR_USERNAMEを実際のGitHubユーザー名に置き換えてください）
git remote add origin https://github.com/YOUR_USERNAME/modified-DeGAUSS-EVproject.git

# または、SSHを使用する場合：
# git remote add origin git@github.com:YOUR_USERNAME/modified-DeGAUSS-EVproject.git

# ブランチ名をmainに変更（既に変更済みの場合は不要）
git branch -M main

# GitHubにプッシュ
git push -u origin main
```

**注意**: もし「remote origin already exists」というエラーが出た場合は、上記の `git remote remove origin` コマンドを実行してから、再度 `git remote add origin` を実行してください。

## 3. 認証

初めてプッシュする場合、GitHubの認証情報の入力が求められる場合があります。
- Personal Access Token (PAT) を使用することを推奨します
- GitHub Settings → Developer settings → Personal access tokens → Tokens (classic) でトークンを作成できます

## 完了

これで、プロジェクトがGitHubにアップロードされました！


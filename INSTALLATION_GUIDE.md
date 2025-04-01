# VideoWaniOS Installation Guide

Follow these steps to get the VideoWaniOS app on your iPad using GitHub.

## Step 1: Create a GitHub Repository

1. Go to [GitHub](https://github.com/) and sign in with your account (or create one if needed)
2. Click the "+" icon in the top right and select "New repository"
3. Name your repository "VideoWaniOS"
4. Leave it as a public repository (needed for GitHub Pages)
5. Click "Create repository"

## Step 2: Upload This Code

Now you need to upload this code to your new repository:

```bash
# On your Mac Mini, navigate to where you extracted these files
cd /path/to/VideoWaniOS/github_build

# Configure git with your GitHub credentials
git remote add origin https://github.com/YOUR_GITHUB_USERNAME/VideoWaniOS.git

# Push the code to GitHub
git push -u origin master
```

Replace `YOUR_GITHUB_USERNAME` with your actual GitHub username.

## Step 3: Enable GitHub Pages

1. Go to your repository on GitHub
2. Click "Settings" at the top
3. Scroll down to "GitHub Pages"
4. Under "Source", select "master" branch
5. Click "Save"
6. Wait a few minutes for GitHub Pages to activate

## Step 4: Run the GitHub Action

1. Go to the "Actions" tab in your repository
2. You should see the "Build iOS App" workflow
3. Click "Run workflow"
4. Wait for the workflow to complete (5-10 minutes)

## Step 5: Get the Built App

1. When the workflow completes, click on the completed run
2. Scroll down to the "Artifacts" section
3. Download the "VideoWaniOS" artifact (this is your IPA file)
4. Download the "build" artifact (contains additional files)

## Step 6: Prepare for Installation

1. Extract the downloaded artifacts
2. Copy the VideoWaniOS.ipa file to the root of your GitHub repository
3. Update the manifest.plist file to include your GitHub username in the URL
4. Commit and push these changes:

```bash
git add VideoWaniOS.ipa
git commit -m "Add built IPA file"
git push
```

## Step 7: Install on Your iPad

1. On your iPad, open Safari
2. Go to: `https://YOUR_GITHUB_USERNAME.github.io/VideoWaniOS/`
3. Tap the "Install VideoWaniOS" button
4. If prompted, tap "Allow" to confirm the installation
5. Go to Settings → General → Device Management and trust the developer profile
6. Launch VideoWaniOS from your home screen

## Alternative: Use the Web Version

If you have trouble with the installation, you can use the web version:

1. On your iPad, open Safari
2. Go to: `https://YOUR_GITHUB_USERNAME.github.io/VideoWaniOS/web_version/`
3. The web version will open directly in your browser
4. You can add it to your home screen by tapping the share button and selecting "Add to Home Screen"

## Need Help?

If you encounter any issues, please refer to the troubleshooting guide or try the web version as an alternative.
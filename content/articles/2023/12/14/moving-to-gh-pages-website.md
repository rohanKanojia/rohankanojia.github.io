---
title: "Moving to a GitHub Pages based Static Website"
draft: false
tags:
- career
- personal-branding
- hugo
- github-pages
date: 2023-12-14
lastmod: 2023-12-14
---

## Why did I decide to build a GitHub Pages static website?

Till now, I had been skipping building a personal website of my own. I used to think it's too much work. I was satisfied with [About.me](https://about.me/rohankanojia) webpage that I had created when I was young. At that time, it was sufficient for my needs. I used to keep my [StackOverflow profile](https://stackoverflow.com/users/2830116/rohan-kumar) and [StackOverFlow Developer Story](https://meta.stackoverflow.com/questions/313960/introducing-the-developer-story) updated from time to time.

However, now at this point in my career, I have too many things scattered everywhere around the internet. I needed some central place where I could list all the blog posts and videos. My manager [Gerard Braad](http://gbraad.nl/) suggested me to build a simple static website on GitHub pages, and I also thought of doing it finally.

## Set Up

I decided to use [hugo](https://gohugo.io/) for generating my portfolio website. It seemed to be the most popular option at the time of writing. It also has a large collection of community-provided themes that can be used to customize the website's layout and appearance.

Getting started with Hugo is just about downloading the binary and running the following commands:
```shell
$ hugo new site site-name
$ cd site-name
$ git init
$ git submodule add https://github.com/nurlansu/hugo-sustain.git themes/hugo-sustain
$ echo "theme = 'hugo-sustain'" >> hugo.toml
$ hugo serve
```

This would make a skeleton website ready to be used. You can tweak various things as per your requirements. I did the following things :
- Change the website home icon to use my name by  providing a hugo partial `header.html`
- Change the website footer to provide a language option (one for English and one for Hindi) by providing a hugo partial `footer.html`
- Tweak CSS provided by theme as per my requirements and placing it in `static/css/main.css` and overriding it in `hugo.toml`:
  ```toml
  [params]
    custom_css = ["css/main.css"]
  ```

## Design/Content Inspiration

I wanted to build a really minimal and simple website. It is mainly inspired by [Matt Farina](https://www.mattfarina.com/)'s design.  I have also ported some content to bio from my colleagues' websites:
- [Marc Nuri San Felix](https://marcnuri.com/)
- [Sun Seng David TAN](https://blog.sunix.org/)

## Localization

I wanted the website to use English as a primary language but also have support for Hindi (my mother language). I understand there isn't much audience for Hindi, but I wanted it just for my own satisfaction.

For now, I just have multiple language options available only on the landing page. I first added the language in Hugo configuration like this:

```toml
DefaultContentLanguage = "en"
[languages]
  [languages.en]
    title = 'John Doe | John Doe'
    languageName = "🇬🇧nglish"
    weight = 1
  [languages.hi]
    title = "जॉन डो| जॉन डो
    languageName = "🇮🇳indi"
    weight = 2
```

Then in the `content/` I have two different versions of `_index.md` (with the former defaulting to the English language):
```sh
$ ls content/
_index.hi.md  _index.md
```

`_index.hi.md` would contain the content in the Hindi language for the landing page.

## Deployment

For deploying the website, I'm using [GitHub Actions](https://github.com/features/actions). I'm executing a docker image inside the GitHub action to generate the final HTML content.

That docker image is created via this Dockerfile:
```Dockerfile
FROM alpine:3.16.0 
ARG HUGO_VERSION=0.120.4-r0
RUN apk add --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community --no-cache hugo=~${HUGO_VERSION}
RUN apk add --update wget nodejs npm hugo
ENV HUGO_ENVIRONMENT=production
ENV HUGO_ENV=production
RUN [[ -f package-lock.json || -f npm-shrinkwrap.json ]] && npm ci || true
RUN npm install -g sass
WORKDIR /usr/src/
ENTRYPOINT ["hugo", "--gc", "--minify", "--baseURL"]
```

I have two GitHub Actions workflows:
- Build Container Image for generating HTML
- Deploy Hugo Site to GitHub pages

The first workflow just builds the container image from the Dockerfile present in the project and pushes it to [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry). It is a manually triggered job, as changes to website container image would not be as frequent.

Build Image GitHub workflow:
```yaml
name: Build Container image for generating HTML content 

on:
  workflow_dispatch:

jobs:
  build-image:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      - name: Log in to the Container registry
        uses: docker/login-action@65b78e6e13532edd9afa3aa52ac7964289d1a9c1
        with:
          registry: ghcr.io 
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - name: Extract metadata (tags, labels) for Docker
        id: meta
        uses: docker/metadata-action@9ec57ed1fcdbf14dcef7dfbe97b2010124a938b7
        with:
          images: ghcr.io/${{ github.repository }}
      - name: Build and push Docker image
        uses: docker/build-push-action@f2a1d5e99d037542a71f64918e516c093c6f3fc4
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```
Each step mentioned in the GitHub Action workflow is described below:
- First repository is cloned using `actions/checkout`
- We do `docker login` into `ghcr.io` container registry using GitHub Username (person who triggered the workflow) and GitHub token used by GitHub Actions.
- We extract required tags and labels for container images to create using `docker/metadata-action`
- Finally, we build a container image and push it to `ghcr.io` using `docker/build-push-action`

The second workflow is executing the docker image generated in the previous workflow to generate the Hugo website. Generated content is uploaded as a GitHub artifact which gets consumed by the final deploy workflow to publish it to GitHub pages. This workflow gets triggered on every push to the repository's main branch.

Deploy Hugo site to GitHub Pages workflow:
```yaml
name: Deploy Hugo site to Pages

on:
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: "pages"
  cancel-in-progress: false

defaults:
  run:
    shell: bash

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          submodules: recursive
          fetch-depth: 0
      - name: Setup Pages
        id: pages
        uses: actions/configure-pages@v4
      - name: Run Docker Image
        run: |
          export USER_NAME=`echo ${{ github.actor }} |  awk '{print tolower($0)}'`
          docker run                                                 \
          --rm                                                       \
          -v `pwd`:/usr/src                                          \
          -w /usr/src/                                               \
          -e LOCAL_USER="$(id -u):$(id -g)"                          \
          ghcr.io/$USER_NAME/${{ github.event.repository.name }}:${{ github.ref_name }} "${{ steps.pages.outputs.base_url }}/"  
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v2
        with:
          path: ./public

  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v3
```

Each step mentioned in the GitHub Action workflow is described below:
- First repository is cloned using `actions/checkout` (including submodules that are used for Hugo theme)
- Enable GitHub pages and extract site metadata using `actions/configure-pages`
- Create a container from the Docker Image created by the build-image workflow:
  ```shell
  # Convert username to lowercase
  $ export USER_NAME=`echo ${{ github.actor }} |  awk '{print tolower($0)}'`
  # Run container and provide base URL as command line argument
  $ docker run                                                       \
          --rm                                                       \
          -v `pwd`:/usr/src                                          \
          -w /usr/src/                                               \
          -e LOCAL_USER="$(id -u):$(id -g)"                          \
          ghcr.io/$USER_NAME/${{ github.event.repository.name }}:${{ github.ref_name }} "${{ steps.pages.outputs.base_url }}/"  
  ```
- The previous step would create a `public/` folder in the current working directory. This folder contains the actual generated website that needs to be deployed to GitHub pages. We upload this as an artifact using `actions/upload-pages-artifact`.
- Finally, in the Deploy workflow we use `actions/deploy-pages` to deploy artifacts uploaded in the previous step.

## Conclusion

Building a static website these days isn't as hard as I thought. With the help of static generation tools, it has become really straightforward. It doesn't require the user to know the intricacies of HTML/CSS hence providing a really nice onboarding experience. If you're also thinking about making your own personal website, you should definitely do it. It can help you in your career and maybe even make you learn new things.

If you're interested code for the website of this repository can be found [here](https://github.com/rohanKanojia/rohankanojia.github.io/tree/main).

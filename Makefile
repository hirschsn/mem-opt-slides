
all:
	pandoc -t revealjs -s slides.md -o out/slides.html -V revealjs-url=https://unpkg.com/reveal.js --include-in-header=style.css -V theme=serif --slide-level 2

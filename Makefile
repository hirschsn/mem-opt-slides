
REVEALJS_URL ?= https://unpkg.com/reveal.js
COMMON_OPT =  -t revealjs -s -V revealjs-url=${REVEALJS_URL} --include-in-header=style.css -V theme=serif --slide-level 2

all:
	pandoc ${COMMON_OPT} slides.md -o index.html

# All resources embedded (to transport on pen drive etc.)
dist:
	 pandoc --embed-resources ${COMMON_OPT} slides.md -o index.dist.html

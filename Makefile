COMMONFORM=node_modules/.bin/commonform
CFTEMPLATE=node_modules/.bin/cftemplate
SPELL=node_modules/.bin/reviewers-edition-spell
OUTPUT=build
GIT_TAG=$(strip $(shell git tag -l --points-at HEAD))
EDITION=$(if $(GIT_TAG),$(GIT_TAG),Development Draft)
BLANK=______________________________

ID=$(wildcard *.cftemplate)
FORM=$(basename $(ID))
DOCX=$(OUTPUT)/$(FORM:=.docx)
PDF=$(OUTPUT)/$(FORM:=.pdf)
MD=$(OUTPUT)/$(FORM:=.md)
JSON=$(OUTPUT)/$(FORM:=.json)
HTML=$(OUTPUT)/$(FORM:=.html)
TARGETS=$(DOCX) $(PDF) $(MD) $(JSON)

all: docx pdf md json html

docx: $(DOCX)

pdf: $(PDF)

md: $(MD)

json: $(JSON)

html: $(HTML)

manifest: $(OUTPUT)/manifest.json

.PHONY: google-drive

google-drive: google-drive-id $(DOCX)
	common/update-google-drive $(shell cat google-drive-id) $(DOCX)

$(OUTPUT):
	mkdir -p $(OUTPUT)

$(OUTPUT)/%.md: $(OUTPUT)/%.cform | $(COMMONFORM) $(SPELL) $(OUTPUT)
	$(COMMONFORM) render --format markdown --title "RxNDA Form $*" --edition "$(shell echo "$(EDITION)" | $(SPELL))" < $< > $@

$(OUTPUT)/%.html: $(OUTPUT)/%.cform | $(COMMONFORM) $(SPELL) $(OUTPUT)
	echo "<!doctype html><html lang=en><head><meta charset='UTF-8'><title>TITLE, EDITION</title></head><body>" \
	| sed 's!TITLE!RxNDA Form $*!' | sed 's!EDITION!$(shell echo "$(EDITION)" | $(SPELL))!' > $@
	$(COMMONFORM) render --format html5 --title "RxNDA Form $*" --edition "$(shell echo "$(EDITION)" | $(SPELL))" < $< >> $@
	echo '</body></html>' >> $@

$(OUTPUT)/%.docx: $(OUTPUT)/%.cform %.signatures | $(COMMONFORM) $(SPELL) $(OUTPUT)
	$(COMMONFORM) render --format docx --blank-text "$(BLANK)" --title "RxNDA Form $*" --edition "$(shell echo "$(EDITION)" | $(SPELL))" --indent-margins --number outline --signatures $*.signatures < $< > $@

$(OUTPUT)/%.cform: %.cftemplate | $(CFTEMPLATE) $(OUTPUT)
ifeq ($(EDITION),Development Draft)
	$(CFTEMPLATE) $< | sed "s!PUBLICATION!This is a development draft of RxNDA Form $*.!" > $@
else
	$(CFTEMPLATE) $< | sed "s!PUBLICATION!RxNDA LLC published this form as RxNDA Form $*, $(shell echo "$(EDITION)" | $(SPELL)).!" > $@
endif

$(OUTPUT)/%.json: $(OUTPUT)/%.cform | $(COMMONFORM) $(OUTPUT)
	$(COMMONFORM) render --format native < $< > $@

%.pdf: %.docx
	doc2pdf $<

$(COMMONFORM) $(CFTEMPLATE) $(SPELL):
	npm install

.PHONY: clean docker test lint critique

test: lint critique

lint: $(JSON) | $(COMMONFORM)
	for form in $(JSON); do $(COMMONFORM) lint < $$form | awk -v prefix="$$(basename $$form .json): " '{print prefix $$0}'; done | tee lint.log

critique: $(JSON) | $(COMMONFORM)
	for form in $(JSON); do $(COMMONFORM) critique < $$form | awk -v prefix="$$(basename $$form .json): " '{print prefix $$0}'; done | tee critique.log

clean:
	rm -rf $(OUTPUT)

DOCKER_TAG=rxnda-form

docker:
	docker build -t $(DOCKER_TAG) -f common/Dockerfile .
	docker run --name $(DOCKER_TAG) $(DOCKER_TAG)
	docker cp $(DOCKER_TAG):/workdir/$(OUTPUT) .
	docker rm $(DOCKER_TAG)

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
MANIFEST=$(OUTPUT)/$(FORM:=.manifest)
TARGETS=$(DOCX) $(PDF) $(MD) $(JSON) $(MANIFEST)

all: docx pdf md json html manifest

docx: $(DOCX)

pdf: $(PDF)

md: $(MD)

json: $(JSON)

html: $(HTML)

manifest: $(MANIFEST)

.PHONY: google-drive

google-drive: google-drive-id $(DOCX)
	common/update-google-drive $(shell cat google-drive-id) $(DOCX)

$(OUTPUT):
	mkdir -p $(OUTPUT)

$(OUTPUT)/%.md: $(OUTPUT)/%.cform | $(COMMONFORM) $(SPELL) $(OUTPUT)
	$(COMMONFORM) render --format markdown --title "Nondisclosure Agreement" --edition "$(shell echo "$(EDITION)" | $(SPELL))" < $< > $@

$(OUTPUT)/%.html: $(OUTPUT)/%.cform | $(COMMONFORM) $(SPELL) $(OUTPUT)
	echo "<!doctype html><html lang=en><head><meta charset='UTF-8'><title>Nondisclosure Agreement</title></head><body>" > $@
	$(COMMONFORM) render --format html5 --title "Nondisclosure Agreement" --edition "$(shell echo "$(EDITION)" | $(SPELL))" < $< >> $@
	echo '</body></html>' >> $@

$(OUTPUT)/%.docx: $(OUTPUT)/%.cform %.signatures | $(COMMONFORM) $(SPELL) $(OUTPUT)
	$(COMMONFORM) render --format docx --blank-text "$(BLANK)" --title "Nondisclosure Agreement" --edition "$(shell echo "$(EDITION)" | $(SPELL))" --indent-margins --number outline --signatures $*.signatures < $< > $@

$(OUTPUT)/%.cform: %.cftemplate | $(CFTEMPLATE) $(OUTPUT)
ifeq ($(EDITION),Development Draft)
	$(CFTEMPLATE) $< | sed "s!PUBLICATION!This is a development draft of RxNDA Form $*.!" > $@
else
	$(CFTEMPLATE) $< | sed "s!PUBLICATION!RxNDA LLC published this form as RxNDA Form $*, $(shell echo "$(EDITION)" | $(SPELL)).!" > $@
endif

$(OUTPUT)/%.json: $(OUTPUT)/%.cform | $(COMMONFORM) $(OUTPUT)
	$(COMMONFORM) render --format native < $< > $@

$(OUTPUT)/%.manifest: $(OUTPUT)/%.json %.description %.signatures | $(COMMONFORM) $(OUTPUT)
	common/build-manifest "$*" "$(EDITION)" > $@

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

all: build

build:
	tpage --define PRO=true  goss.json > goss_pro.json.tt2
	tpage                    goss.json > goss_ce.json.tt2

clean:
	rm goss_*.tt2

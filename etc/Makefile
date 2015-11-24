all: build

build:
	tpage --define PRO=true  goss.json > goss_pro.json.tt2
	tpage                    goss.json > goss_ce.json.tt2
	tpage --define PRO=true  01_hostname-and-interfaces.json > 01_hostname-and-interfaces.json.tt2
	tpage                    01_hostname-and-interfaces.json > 01_hostname-and-interfaces.json.tt2
	tpage --define PRO=true  01_running-processes.json > 01_running-processes.json.tt2
	tpage                    01_running-processes.json > 01_running-processes.json.tt2
	tpage --define PRO=true  02_disk-free.json > 02_disk-free.json.tt2
	tpage                    02_disk-free.json > 02_disk-free.json.tt2
	tpage --define PRO=true  03_files_availability.json > 03_files_availability.json.tt2
	tpage                    03_files_availability.json > 03_files_availability.json.tt2
	tpage --define PRO=true  03_no-cores.json > 03_no-cores.json.tt2
	tpage                    03_no-cores.json > 03_no-cores.json.tt2
	tpage --define PRO=true  04_template_files.json > 04_template_files.json.tt2
	tpage                    04_template_files.json > 04_template_files.json.tt2
	tpage --define PRO=true  05_system_users.json > 05_system_users.json.tt2
	tpage                    05_system_users.json > 05_system_users.json.tt2
	tpage --define PRO=true  06_system_packages.json > 06_system_packages.json.tt2
	tpage                    06_system_packages.json > 06_system_packages.json.tt2
	tpage --define PRO=true  07_system_service.json > 07_system_service.json.tt2
	tpage                    07_system_service.json > 07_system_service.json.tt2
	tpage --define PRO=true  08_system_ports.json > 08_system_ports.json.tt2
	tpage                    08_system_ports.json > 08_system_ports.json.tt2
	tpage --define PRO=true  09_system_dns.json > 09_system_dns.json.tt2
	tpage                    09_system_dns.json > 09_system_dns.json.tt2
	tpage --define PRO=true  99_dummy.json > 99_dummy.json.tt2
	tpage                    99_dummy.json > 99_dummy.json.tt2

clean:
	rm -f goss_*.tt2

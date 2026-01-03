#!/bin/sh

curl -sL https://standards-oui.ieee.org/oui/oui.csv | \
awk -F',' 'BEGIN { print "prefix,manufacturer" }
	NR>1 && $2 != "" { 
    # Formata o MAC de XXXXXX para xx:xx:xx (minúsculo para bater com seus logs)
    mac = tolower(substr($2,1,2)":"substr($2,3,2)":"substr($2,5,2));
    
    # Remove aspas extras do nome do fabricante se houver e imprime
    gsub(/"/, "", $3);
    print mac "," "\"" $3 "\"" 
}' > /etc/vector/oui.csv && rc-service vector -v reload

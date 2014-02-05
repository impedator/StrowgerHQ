#!/bin/bash

#Skrypt do wrzucania dokumentów na środowisko testowe z pominięciem SmartFix

#Katalog w którym są wsady produkcyjne:
export prod_stack_dir=/cygdrive/z/

#Katalog dla wsadów na TST
export tst_stack_dir=/input

#Katalog Exchange SmartFixa
export exchange_dir=/exchange/

for stack_dir in $prod_stack_dir*
do
	echo =====================================================================
	echo ========== Aktualnie procesowany dir $stack_dir
	echo =====================================================================
	date +%c >> /var/log/sf.log
	echo ========== Aktualnie procesowany dir $stack_dir >> /var/log/sf.log
	
	net stop ECMSFIntegrationServiceScan1
        echo =====================================================================
	echo Dokumenty wsadu:
	for stack_docs in `find $stack_dir -name *.tif`
	do
		echo $stack_docs
		cp $stack_docs $tst_stack_dir
	done 
	echo "*********************************************************************"

	for export_file in `find $stack_dir -name Export.xml`
	do
		echo Plik exportu z PRODa $export_file
		export file_timestamp=`date +%s`
		echo Plik exportu do modyfikacji /tmp/"$file_timestamp"_export.xml
		cp $export_file /tmp/"$file_timestamp"_export.xml
	done

	net start ECMSFIntegrationServiceScan1
	while [ ! -s /tmp/"$file_timestamp"_import.xml ] ;
	do
		sleep 2
		echo -n .
		import_file_wait=`find $exchange_dir -name import.xml`
		if [ `find $exchange_dir -name import.xml | wc -l` -eq 1 ] ; then cp $import_file_wait /tmp/"$file_timestamp"_import.xml ; fi 
#		echo $exchange_dir $import_file_wait
		
	done
#	echo Dir z procesowanym aktualnie wsadem $exchange_dir
	echo Aktualny plik importu /tmp/"$file_timestamp"_import.xml
	rm -rf $import_file_wait
        net stop ECMSFIntegrationServiceScan1

	export export_dir_original=`echo $import_file_wait | awk '{print substr($1,0,50)}'`
	echo export.xml destination: $export_dir_original

	export import_file=/tmp/"$file_timestamp"_import.xml

	case `grep StackID $import_file | awk '{print substr ($3,11,9)}'` in
 		Faktura\" ) stackID_length=39;;
 		Rachunek\" ) stackID_length=40;;
		NotaObciazeniowa\") stackID_length=48;;
	esac
#	echo Dlugosc = $stackID_length

	case `grep StackID /tmp/"$file_timestamp"_export.xml | awk '{print substr ($4,11,17)}'` in
		Faktura\" ) old_stackID_length=39;;
                Rachunek\" ) old_stackID_length=40;;
                NotaObciazeniowa\") old_stackID_length=48;;
        esac
#        echo Dlugosc_old = $old_stackID_length

			 
	export stackID=`grep StackID $import_file | awk -v sIDlength="$stackID_length" '{print substr($6,10,sIDlength)}'`
#	echo $stackID

	export old_stackID=`grep StackID /tmp/"$file_timestamp"_export.xml | awk -v sIDlength="$old_stackID_length" '{print substr($5,10,sIDlength)}'`
#	echo $old_stackID
	echo zamiana ID wsadów w export.xml:
	echo OLD: $old_stackID
	echo NEW: $stackID

	perl -p -i -e "s/$old_stackID/$stackID/g" /tmp/"$file_timestamp"_export.xml
	perl -p -i -e 's/\\\\ECM-SF\\Exchange\\/\\\\TSTECM02\\smartFIX-System\\DokumentyKosztowe\\Exchange\\/g' /tmp/"$file_timestamp"_export.xml
	
	cp /tmp/"$file_timestamp"_export.xml "$export_dir_original"Export.xml

	rm -r $stack_dir 
	
        echo _____________________________________________________________________ 
        echo ========== Zakonczono procesowanie $stack_dir
        echo ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
	echo ========== Zakonczono procesowanie $stack_dir >> /var/log/sf.log	
done


#!/bin/bash

#Skrypt do wrzucania dokumentów na środowisko testowe z pominięciem SmartFix

#Katalog w którym są wsady produkcyjne:
export prod_stack_dir=/cygdrive/z/

#Katalog dla wsadów na TST
export tst_stack_dir=/input

#Katalog Exchange SmartFixa
export exchange_dir=/exchange/

loop_start_routine ()
{
	echo ;
	echo =====================================================================;
        echo ========== Current working dir $1 ;
        echo =====================================================================;
	if [ -f $1/.lock ]
	then
		echo "Dir locked, skipping...";
		continue;
	fi

	touch $1/.lock ;

        date +%c >> /var/log/sf.log ;
        echo ========== Current working dir $1 >> /var/log/sf.log ;
	if [ `net start | grep ECMSFIntegrationServiceScan1` ]; then net stop ECMSFIntegrationServiceScan1 ; fi
        echo "*********************************************************************";
}

loop_end_routine ()
{
        if [ `net start | grep ECMSFIntegrationServiceScan1` ]; then net stop ECMSFIntegrationServiceScan1 ; fi
        rm -r $1

        echo _____________________________________________________________________
        echo ========== All done in $1
        echo ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
        echo ========== All done in $1 >> /var/log/sf.log
        rm -rf $1/.lock
}



main_loop ()
{
for stack_dir in $prod_stack_dir*
do
	loop_start_routine $stack_dir

	echo Stack documents:
	for stack_docs in `find $stack_dir -name *.tif`
	do
		echo $stack_docs
		cp $stack_docs $tst_stack_dir
	done 
	echo "*********************************************************************"

	for export_file in `find $stack_dir -name Export.xml`
	do
		echo Export file from PROD $export_file
		export file_timestamp=`date +%s`
		echo Export file for corrections /tmp/"$file_timestamp"_export.xml
		cp $export_file /tmp/"$file_timestamp"_export.xml
	done

	if [ ! `net start | grep ECMSFIntegrationServiceScan1` ]; then net start ECMSFIntegrationServiceScan1 ; fi
	import_timeout=0
	while [ ! -s /tmp/"$file_timestamp"_import.xml ] ;
	do
		sleep 2
		echo -n .
		import_file_wait=`find $exchange_dir -name import.xml`
		if [ `find $exchange_dir -name import.xml | wc -l` -eq 1 ] ; then cp $import_file_wait /tmp/"$file_timestamp"_import.xml ; fi 
                import_timeout=$(($import_timeout+1))

                if [ "$import_timeout" -gt 20 ]
                then
			echo ;
			echo "Stack problem, most likely duplicate or stack empty..."
			loop_end_routine $stack_dir
			continue 2
                        break 
                fi
		
	done
	echo ;
	echo Current import file: /tmp/"$file_timestamp"_import.xml
	rm -rf $import_file_wait
	if [ `net start | grep ECMSFIntegrationServiceScan1` ]; then net stop ECMSFIntegrationServiceScan1 ; fi

	export export_dir_original=`echo $import_file_wait | awk '{print substr($1,0,50)}'`
	echo export.xml destination: $export_dir_original

	export import_file=/tmp/"$file_timestamp"_import.xml

	case `grep StackID $import_file | awk '{print substr ($3,11,9)}'` in
 		Faktura\" ) stackID_length=39;;
 		Rachunek\" ) stackID_length=40;;
		NotaObciazeniowa\") stackID_length=48;;
	esac

	case `grep StackID /tmp/"$file_timestamp"_export.xml | awk '{print substr ($4,11,17)}'` in
		Faktura\" ) old_stackID_length=39;;
                Rachunek\" ) old_stackID_length=40;;
                NotaObciazeniowa\") old_stackID_length=48;;
        esac

			 
	export stackID=`grep StackID $import_file | awk -v sIDlength="$stackID_length" '{print substr($6,10,sIDlength)}'`

	export old_stackID=`grep StackID /tmp/"$file_timestamp"_export.xml | awk -v sIDlength="$old_stackID_length" '{print substr($5,10,sIDlength)}'`
	echo StackID swap in export.xml file:
	echo OLD: $old_stackID
	echo NEW: $stackID

	perl -p -i -e "s/$old_stackID/$stackID/g" /tmp/"$file_timestamp"_export.xml
	perl -p -i -e 's/\\\\ECM-SF\\Exchange\\/\\\\TSTECM02\\smartFIX-System\\DokumentyKosztowe\\Exchange\\/g' /tmp/"$file_timestamp"_export.xml
	
	cp /tmp/"$file_timestamp"_export.xml "$export_dir_original"Export.xml

	loop_end_routine $stack_dir
done
}



if [ -f /tmp/sf-sync.lock ]
then
echo "Another instance not allowed...";
exit 1;
fi
 
touch /tmp/sf-sync.lock
 
if [ ! -d /cygdrive/z  ]; then net use Z: \\\\10.36.26.203\\d$\\temp ; fi


#Check if prod_stack_dir is empty:
ls $prod_stack_dir/*/ >/dev/null 2>&1 ;
if [ $? == 0 ]; then echo Some data in stack folder found, analizing...; main_loop ; else echo Stack folder empty, aborting...; fi
 
rm /tmp/sf-sync.lock 
 
exit 0;


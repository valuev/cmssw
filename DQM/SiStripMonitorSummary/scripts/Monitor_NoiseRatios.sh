#!/bin/bash

date
# needed to allow the loop on *.png without using "*.png" as value
shopt -s nullglob

if [ $# -ne 4 ]; then
    afstokenchecker.sh "You have to provide a <DB>, an <Account>, a <GTAccount> and the <FrontierPath> !!!"
    exit
fi

afstokenchecker.sh "Starting execution of Monitor_NoiseRatios $1 $2 $3 $4"

#Example: DB=cms_orcoff_prod
DB=$1
#Example: ACCOUNT=CMS_COND_21X_STRIP
ACCOUNT=$2
#Example: GTACCOUNT=CMS_COND_21X_GLOBALTAG
GTACCOUNT=$3
#Example: FRONTIER=FrontierProd
FRONTIER=$4
DBTAGCOLLECTION=DBTagsIn_${DB}_${ACCOUNT}.txt
GLOBALTAGCOLLECTION=GlobalTagsForDBAccount.txt
DBTAGDIR=DBTagCollection
GLOBALTAGDIR=GlobalTags
STORAGEPATH=/afs/cern.ch/cms/tracker/sistrcalib/WWW/CondDBMonitoring
WORKDIR=$PWD

#Function to publish png pictures on the web. Will be used at the end of the script:
CreateIndex ()
{
    cp /afs/cern.ch/cms/tracker/sistrcalib/WWW/index_new.html .

    COUNTER=0
    LASTUPDATE=`date`

    for Plot in *.png; do
	if [[ $COUNTER%2 -eq 0 ]]; then
	    cat >> index_new.html  << EOF
<TR> <TD align=center> <a href="$Plot"><img src="$Plot"hspace=5 vspace=5 border=0 style="width: 90%" ALT="$Plot"></a> 
  <br> $Plot </TD>
EOF
	else
	    cat >> index_new.html  << EOF
  <TD align=center> <a href="$Plot"><img src="$Plot"hspace=5 vspace=5 border=0 style="width: 90%" ALT="$Plot"></a> 
  <br> $Plot </TD> </TR> 
EOF
	fi

	let COUNTER++
    done

    cat ${CMSSW_BASE}/src/DQM/SiStripMonitorSummary/data/template_index_foot.html | sed -e "s@insertDate@$LASTUPDATE@g" >> index_new.html

    mv -f index_new.html index.html
}

# Creation of all needed directories if not existing yet
if [ ! -d "$STORAGEPATH/$DB" ]; then 
    afstokenchecker.sh "Creating directory $STORAGEPATH/$DB"
    mkdir $STORAGEPATH/$DB;
fi

if [ ! -d "$STORAGEPATH/$DB/$ACCOUNT" ]; then 
    afstokenchecker.sh "Creating directory $STORAGEPATH/$DB/$ACCOUNT"
    mkdir $STORAGEPATH/$DB/$ACCOUNT; 
fi

if [ ! -d "$STORAGEPATH/$DB/$ACCOUNT/$DBTAGDIR" ]; then 
    afstokenchecker.sh "Creating directory $STORAGEPATH/$DB/$ACCOUNT/$DBTAGDIR"
    mkdir $STORAGEPATH/$DB/$ACCOUNT/$DBTAGDIR; 
fi

# Array of already analyzed tags

declare -a checkedtags;

# Access of all Global Tags contained in the given DB account
cmscond_tagtree_list -c frontier://cmsfrontier.cern.ch:8000/$FRONTIER/$GTACCOUNT -P /afs/cern.ch/cms/DB/conddb | grep tree | awk '{print $2}' > $GLOBALTAGCOLLECTION

TAGSUBDIR=SiStripNoise

# Loop on all Global Tags
for globaltag in `cat $GLOBALTAGCOLLECTION`; do

    afstokenchecker.sh "Processing Global Tag $globaltag";

    NEWTAG=False
    NEWIOV=False
    CFGISSAVED=False
    LOGDESTINATION=cout

    NOISETAGANDOBJECT=`cmscond_tagtree_list -c frontier://cmsfrontier.cern.ch:8000/$FRONTIER/$GTACCOUNT -P /afs/cern.ch/cms/DB/conddb -T $globaltag | grep SiStripNoise | grep $ACCOUNT | awk '{printf "%s %s",$3,$5}'`

    if [ `echo $NOISETAGANDOBJECT | wc -w` -eq 0 ]; then
	continue
    fi

    NOISETAG=`echo $NOISETAGANDOBJECT | awk '{print $1}' | sed -e "s@tag:@@g"`
    NOISEOBJECT=`echo $NOISETAGANDOBJECT | awk '{print $2}' | sed -e "s@object:@@g"`

    if [ `echo $NOISETAG | grep Ideal | wc -w` -gt 0 ]; then
	continue
    fi

# grep modified to get ONLY the SiStripApvGainRcd but not the SiStripApvGain2Rcd nor the SiStripApvGainSimRcd
    GAINTAGANDOBJECT=`cmscond_tagtree_list -c frontier://cmsfrontier.cern.ch:8000/$FRONTIER/$GTACCOUNT -P /afs/cern.ch/cms/DB/conddb -T $globaltag | grep "record:SiStripApvGainRcd" | grep $ACCOUNT | awk '{printf "%s %s",$3,$5}'`

    if [ `echo $GAINTAGANDOBJECT | wc -w` -eq 0 ]; then
	continue
    fi

    GAINTAG=`echo $GAINTAGANDOBJECT | awk '{print $1}' | sed -e "s@tag:@@g"`
    GAINOBJECT=`echo $GAINTAGANDOBJECT | awk '{print $2}' | sed -e "s@object:@@g"`

    tag=${NOISETAG}_${GAINTAG}
    # check if $tag contains blank and if so, issue a warning
    if [ `expr index "$tag" " "` -ne 0 ]; then
	afstokenchecker.sh "WARNING!! $tag has blank spaces"
    fi


    # Creation of DB-Tag directory if not existing yet
    if [ ! -d "$STORAGEPATH/$DB/$ACCOUNT/$DBTAGDIR/$TAGSUBDIR" ]; then 
	afstokenchecker.sh "Creating directory $STORAGEPATH/$DB/$ACCOUNT/$DBTAGDIR/$TAGSUBDIR"
	mkdir $STORAGEPATH/$DB/$ACCOUNT/$DBTAGDIR/$TAGSUBDIR; 
    fi

    if [ ! -d "$STORAGEPATH/$DB/$ACCOUNT/$DBTAGDIR/$TAGSUBDIR/NoiseRatios" ]; then 
	afstokenchecker.sh "Creating directory $STORAGEPATH/$DB/$ACCOUNT/$DBTAGDIR/$TAGSUBDIR/NoiseRatios"
	mkdir $STORAGEPATH/$DB/$ACCOUNT/$DBTAGDIR/$TAGSUBDIR/NoiseRatios; 
    fi

    if [ ! -d "$STORAGEPATH/$DB/$ACCOUNT/$DBTAGDIR/$TAGSUBDIR/NoiseRatios/$tag" ]; then 
	afstokenchecker.sh "Creating directory $STORAGEPATH/$DB/$ACCOUNT/$DBTAGDIR/$TAGSUBDIR/NoiseRatios/$tag"
	mkdir $STORAGEPATH/$DB/$ACCOUNT/$DBTAGDIR/$TAGSUBDIR/NoiseRatios/$tag;

	NEWTAG=True
    fi

    if [ ! -d "$STORAGEPATH/$DB/$ACCOUNT/$DBTAGDIR/$TAGSUBDIR/NoiseRatios/$tag/RelatedGlobalTags" ]; then 
	afstokenchecker.sh "Creating directory $STORAGEPATH/$DB/$ACCOUNT/$DBTAGDIR/$TAGSUBDIR/NoiseRatios/$tag/RelatedGlobalTags"
	mkdir $STORAGEPATH/$DB/$ACCOUNT/$DBTAGDIR/$TAGSUBDIR/NoiseRatios/$tag/RelatedGlobalTags;
    fi

    # Creation of Global Tag directory if not existing yet
    if [ ! -d "$STORAGEPATH/$DB/$ACCOUNT/$GLOBALTAGDIR" ]; then 
	afstokenchecker.sh "Creating directory $STORAGEPATH/$DB/$ACCOUNT/$GLOBALTAGDIR"
	mkdir $STORAGEPATH/$DB/$ACCOUNT/$GLOBALTAGDIR;
    fi

    if [ ! -d "$STORAGEPATH/$DB/$ACCOUNT/$GLOBALTAGDIR/$globaltag" ]; then 
	afstokenchecker.sh "Creating directory $STORAGEPATH/$DB/$ACCOUNT/$GLOBALTAGDIR/$globaltag"
	mkdir $STORAGEPATH/$DB/$ACCOUNT/$GLOBALTAGDIR/$globaltag;
    fi

    if [ ! -d "$STORAGEPATH/$DB/$ACCOUNT/$GLOBALTAGDIR/$globaltag/NoiseRatio" ]; then 
	afstokenchecker.sh "Creating directory $STORAGEPATH/$DB/$ACCOUNT/$GLOBALTAGDIR/$globaltag/NoiseRatio"
	mkdir $STORAGEPATH/$DB/$ACCOUNT/$GLOBALTAGDIR/$globaltag/NoiseRatio;
    fi

    # Creation of links between the DB-Tag and the respective Global Tags
    cd $STORAGEPATH/$DB/$ACCOUNT/$GLOBALTAGDIR/$globaltag/NoiseRatio;
    if [ -f $tag ]; then
	rm $tag;
    fi
    cat >> $tag << EOF
<html>
<body>
<a href="https://test-stripdbmonitor.web.cern.ch/test-stripdbmonitor/CondDBMonitoring/$DB/$ACCOUNT/$DBTAGDIR/$TAGSUBDIR/NoiseRatios/$tag">https://test-stripdbmonitor.web.cern.ch/test-stripdbmonitor/CondDBMonitoring/$DB/$ACCOUNT/$DBTAGDIR/$TAGSUBDIR/NoiseRatios/$tag</a>
</body>
</html>
EOF
    #ln -s $STORAGEPATH/$DB/$ACCOUNT/$DBTAGDIR/$TAGSUBDIR/$tag $tag;
    cd $STORAGEPATH/$DB/$ACCOUNT/$DBTAGDIR/$TAGSUBDIR/NoiseRatios/$tag/RelatedGlobalTags;
    if [ -f $globaltag ]; then
	rm $globaltag;
    fi
    cat >> $globaltag << EOF
<html>
<body>
<a href="https://test-stripdbmonitor.web.cern.ch/test-stripdbmonitor/CondDBMonitoring/$DB/$ACCOUNT/$GLOBALTAGDIR/$globaltag">https://test-stripdbmonitor.web.cern.ch/test-stripdbmonitor/CondDBMonitoring/$DB/$ACCOUNT/$GLOBALTAGDIR/$globaltag</a>
</body>
</html>
EOF
    #ln -s $STORAGEPATH/$DB/$ACCOUNT/$GLOBALTAGDIR/$globaltag $globaltag;
    cd $WORKDIR;

# check if the tag has been analyzed already

    ALREADYCHECKED=0;

    for checkedtag in ${checkedtags[*]}; do
	if [ $checkedtag == $tag ]; then
	    ALREADYCHECKED=1
	fi
    done

    if [ $ALREADYCHECKED -eq 1 ]; then
	date "+[%c] Tags $tag already checked: skip"
	continue
    fi

    checkedtags[${#checkedtags[*]}]=$tag;

    # Get the list of IoVs for the given DB-Tag
    iov_list_tag.py -c frontier://cmsfrontier.cern.ch:8000/$FRONTIER/$ACCOUNT -P /afs/cern.ch/cms/DB/conddb -t $NOISETAG > list_Iov.txt # Access via Frontier

    # Access DB for the given DB-Tag and dump histograms in .png if not existing yet
    afstokenchecker.sh "Now the values of $tag are retrieved from the DB..."
    
    if [ ! -d "$STORAGEPATH/$DB/$ACCOUNT/$DBTAGDIR/$TAGSUBDIR/NoiseRatios/$tag/rootfiles" ]; then
	mkdir $STORAGEPATH/$DB/$ACCOUNT/$DBTAGDIR/$TAGSUBDIR/NoiseRatios/$tag/rootfiles;
	mkdir $STORAGEPATH/$DB/$ACCOUNT/$DBTAGDIR/$TAGSUBDIR/NoiseRatios/$tag/cfg;
	mkdir $STORAGEPATH/$DB/$ACCOUNT/$DBTAGDIR/$TAGSUBDIR/NoiseRatios/$tag/plots;
    fi

# replaced by the loop below
#    if [ `ls *.png | wc -w` -gt 0 ]; then
#	rm *.png;
#    fi

    for OldPlot in *.png; do
	rm $OldPlot;
    done;

    # Process each IOV of the given DB-Tag seperately
    for IOV_number in `cat list_Iov.txt`; do

	if [ $IOV_number -eq 1 ]; then
	    FirstRun=$IOV_number
	    continue
	fi

	SecondRun=$IOV_number

	ROOTFILE="${tag}_Run_${IOV_number}.root"

	if [ -f $STORAGEPATH/$DB/$ACCOUNT/$DBTAGDIR/$TAGSUBDIR/NoiseRatios/$tag/rootfiles/$ROOTFILE ]; then # Skip IOVs already processed. Take only new ones.
	    FirstRun=$IOV_number
	    continue
	fi

	afstokenchecker.sh "New IOV $IOV_number found. Being processed..."

	NEWIOV=True

	afstokenchecker.sh "Executing cmsRun. Stay tuned ..."

	CMSRUNCOMMAND="cmsRun ${CMSSW_BASE}/src/DQM/SiStripMonitorSummary/test/SiStripCorrelateNoise_conddbmonitoring_cfg.py print connectionString=frontier://$FRONTIER/$ACCOUNT noiseTagName=$NOISETAG gainTagName=$GAINTAG firstRunNumber=$FirstRun secondRunNumber=$SecondRun"
	$CMSRUNCOMMAND

	FirstRun=$IOV_number

	afstokenchecker.sh "cmsRun finished. Now moving the files to the corresponding directories ..."

#	if [ "$NEWTAG" = "True" ] && [ "$CFGISSAVED" = "False" ]; then
	cp ${CMSSW_BASE}/src/DQM/SiStripMonitorSummary/test/SiStripCorrelateNoise_conddbmonitoring_cfg.py SiStripCorrelateNoise_cfg.py 
	cat >> SiStripCorrelateNoise_cfg.py <<EOF
#
# $CMSRUNCOMMAND
#
EOF
	mv SiStripCorrelateNoise_cfg.py $STORAGEPATH/$DB/$ACCOUNT/$DBTAGDIR/$TAGSUBDIR/NoiseRatios/$tag/cfg/${tag}_cfg.py
	CFGISSAVED=True
#	fi

	mv correlTest.root $STORAGEPATH/$DB/$ACCOUNT/$DBTAGDIR/$TAGSUBDIR/NoiseRatios/$tag/rootfiles/$ROOTFILE;

	rm out.log

	for Plot in *.png; do
	    mv $Plot $STORAGEPATH/$DB/$ACCOUNT/$DBTAGDIR/$TAGSUBDIR/NoiseRatios/$tag/plots;
	done;


	#cd $WORKDIR;

    done;

    # Run the Trends and Publish all histograms on a web page
    if [ "$NEWTAG" = "True" ] || [ "$NEWIOV" = "True" ]; then

	afstokenchecker.sh "Publishing the new tag $tag (or the new IOV) on the web ..."

	cd /afs/cern.ch/cms/tracker/sistrcalib/WWW;
	cat ${CMSSW_BASE}/src/DQM/SiStripMonitorSummary/data/template_index_header.html | sed -e "s@insertPageName@Noise Ratios for $NOISETAG and $GAINTAG@g" > index_new.html

	cd $STORAGEPATH/$DB/$ACCOUNT/$DBTAGDIR/$TAGSUBDIR/NoiseRatios/$tag/plots;
	CreateIndex

    fi

    cd $WORKDIR;

done;

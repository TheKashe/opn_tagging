#!/bin/sh

#Community provided script for tagging OPN resources in OCI tenancy.

#!WARNING!

#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, 
#EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
#IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES 
#OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
#ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE 
#OR OTHER DEALINGS IN THE SOFTWARE.

#See README.md for usage

create_opn_tag_namespace()
{
    if [[ ! opn_tag_namespace.sh  ]]
    then
        echo "it seems you have already created the namespace and not deleted it or deleted it manually"
        echo "If you deleted it manually, remove opnt_tag_namespace.sh file"
        return 1
    fi
    TAG_NAMESPACE_NAME="OPN" #for testing we might change that
    TENANCY_OCID=$(oci iam compartment list \
    --all \
    --compartment-id-in-subtree true \
    --access-level ACCESSIBLE \
    --include-root \
    --raw-output \
    --query "data[?contains(\"id\",'tenancy')].id | [0]")

    TAG_NAMESPACE_OCID=$(oci iam tag-namespace create -c $TENANCY_OCID --name $TAG_NAMESPACE_NAME --description "Tags to identify OPN resources" | \
    jq -r '.data.id')

    TAG_PARTNERID_OCID=$(oci iam tag create --tag-namespace-id $TAG_NAMESPACE_OCID --name PartnerID --description "OPN Implementor id" |\
    jq -r '.data.id')

    TAG_OPPYID_OCID=$(oci iam tag create --tag-namespace-id $TAG_NAMESPACE_OCID --name OpportunityID --description "OPN Opportunity id" |\
    jq -r '.data.id')

    TAG_WORKLOAD_OCID=$(oci iam tag create --tag-namespace-id $TAG_NAMESPACE_OCID --name Workload --description "OPN Workload id" --validator  \
    '{ 
        "validatorType": "ENUM", 
        "values": [ 
        "App Integration",
        "Big compute / HPC Workload",
        "Big Data",
        "Cloud Analytics with OAC standalone",
        "Cloud Backup or DR for on-prem",
        "Cloud Native Application Development (ISV customer)",
        "Cloud Native Application Development and AI Services",
        "Consolidate Databases to ADB/ExaDB/Exadata",
        "Create Low code applications on OCI",
        "Data Science",
        "Data Warehouse",
        "Database cybersecurity: on-prem and multi-cloud",
        "Database management: hybrid and multi-cloud",
        "Enterprise Data Lakehouse",
        "Extend Apps with Digital Assistant/Chatbots",
        "Migrate EBS",
        "Migrate from MySQL compatible databases to MySQL Database Service",
        "Migrate from MySQL compatible databases to MySQL HeatWave",
        "Migrate Hyperion",
        "Migrate Java Apps (incl WebLogic)",
        "Migrate JDE",
        "Migrate non-Oracle DB ISV Apps (ISV customer)",
        "Migrate object store and analytics databases to MySQL HeatWave",
        "Migrate Oracle DB ISV Apps (ISV customer)",
        "Migrate Oracle GBU Apps",
        "Migrate other custom non-Oracle Apps",
        "Migrate other custom Oracle DB Apps",
        "Migrate Other Oracle Packaged Apps",
        "Migrate PSFT",
        "Migrate SBL",
        "Multi-Cloud DR"
        ] 
    }'  |\
    jq -r '.data.id')

    echo "TENANCY_OCID=$TENANCY_OCID" > opn_tag_namespace.sh
    echo "TAG_NAMESPACE_OCID=$TAG_NAMESPACE_OCID" >> opn_tag_namespace.sh
    echo "TAG_PARTNERID_OCID=$TAG_PARTNERID_OCID" >> opn_tag_namespace.sh
    echo "TAG_OPPYID_OCID=$TAG_OPPYID_OCID" >> opn_tag_namespace.sh
    echo "TAG_WORKLOAD_OCID=$TAG_WORKLOAD_OCID" >> opn_tag_namespace.sh
    echo "TAG_NAMESPACE_NAME=$TAG_NAMESPACE_NAME" >> opn_tag_namespace.sh
}

delete_opn_tag_namespace(){
    if [[ ! -f opn_tag_namespace.sh  ]]
    then
        echo "it seems the namespace has not been created through a script, can't proceed"
        return 1
    fi
    source opn_tag_namespace.sh 
    oci iam tag retire --tag-namespace-id $TAG_NAMESPACE_OCID --tag-name PartnerID &&
    oci iam tag retire --tag-namespace-id $TAG_NAMESPACE_OCID --tag-name OpportunityID &&
    oci iam tag retire --tag-namespace-id $TAG_NAMESPACE_OCID --tag-name Workload &&
    oci iam tag-namespace retire --tag-namespace-id $TAG_NAMESPACE_OCID &&
    oci iam tag delete --tag-namespace-id $TAG_NAMESPACE_OCID --tag-name PartnerID --force &&
    oci iam tag delete --tag-namespace-id $TAG_NAMESPACE_OCID --tag-name OpportunityID --force &&
    oci iam tag delete --tag-namespace-id $TAG_NAMESPACE_OCID --tag-name Workload --force &&
    oci iam tag-namespace delete --tag-namespace-id $TAG_NAMESPACE_OCID --force &&
    rm opn_tag_namespace.sh
}

#



#test
#tag_resources ocid1.compartment.oc1..aaaaaaaammgumtcs2c4opy5pynvxsr3qpvqtbve5fykcdobcracwg5yj2zmq Testing123 Oppy123 "Create Low code applications on OCI"
tag_resources()
{
    if [[ ! -f opn_tag_namespace.sh  ]]
    then
        echo "it seems the namespace has not been created through a script, can't proceed"
        return 1
    fi
    source opn_tag_namespace.sh 
    # it is not entierly clear what the compartment id is.. 
    # documentation says "The OCID of the compartment where the bulk tag edit request is submitted."
    # But it seems resources outside of the compartment can still be tagged
    local COMPARTMENT_ID=$1
    local PARTNER_ID=$2
    local OPPY_ID=$3
    local WORKLOAD_NAME=$4
    local RESOURCES_JSON=$5
    echo "Tagging resources with PartnerID: ${PARTNER_ID}, OpportunityID: ${OPPY_ID}, Workload: ${WORKLOAD_NAME}"
    oci iam tag bulk-edit -c $COMPARTMENT_ID --resources "file://${RESOURCES_JSON}" --bulk-edit-operations \
    '[{
        "definedTags": {
        "OPN": {
            "PartnerID"     : '\""$PARTNER_ID\""',
            "OpportunityID" : '\""$OPPY_ID\""',
            "Workload"     : '\""$WORKLOAD_NAME\""'
        }},
        "operationType": "ADD_OR_SET"
    }]
    '
}

find_resources_in_compartment(){
    #echo
    local COMPARTMENT_ID=$1
    local RESOURCES_JSON=$2
    local SEARCH_OUT="resource_search_part.json"
    #1. execute surch for all non-terminated resources in compartment
    #   if page is provided in 3rd param it is passed on to search to continue from where it left
    if [ -z ${3+x} ]
    then
        echo "Finding resources in compartment ${COMPARTMENT_ID}" 
        oci search resource structured-search --limit 100 --query-text "query all resources where lifeCycleState != 'TERMINATED' && compartmentId = '$COMPARTMENT_ID'" >$SEARCH_OUT
    else 
        echo "Finding next page of resources in compartment ${COMPARTMENT_ID}" 
        eval oci search resource structured-search  --page $3 --limit 100 --query-text '"'query all resources where lifeCycleState != \'TERMINATED\' \&\& compartmentId = \'$COMPARTMENT_ID\''"' >$SEARCH_OUT
    fi
    #echo oci search resource structured-search $PAGE --limit 100 --query-text '"query all resources where lifeCycleState != 'TERMINATED' && compartmentId = '$COMPARTMENT_ID'"'
    
    #2. Transform the resulting json to the format needed for tagging input
    #   Also filtering out resource types which are not supported by bulk tagging
    #   this list is not exhaustive - it's built by trial and error
    #   if you get an error that resource type is not supported, add a | select... line below for that type
    jq '.data.items[] | select( ."resource-type" != "VaultSecret" ) 
                      | select( ."resource-type" != "PrivateIp") 
                      | select( ."resource-type" != "DrgAttachment")
                      | select( ."resource-type" != "DrgRouteTable")
                      | select( ."resource-type" != "DrgRouteDistribution")  
                      | select( ."resource-type" != "NetworkSecurityGroup")   
                      | select( ."resource-type" != "DbNode")   
                      | select( ."resource-type" != "Bucket")   
                      | select( ."resource-type" != "Key")  
                      | select( ."resource-type" != "CustomerDnsZone") 
                      | select( ."resource-type" != "DnsResolver")   
                      | select( ."resource-type" != "DataSafeUserAssessment") 
                      | select( ."resource-type" != "DataSafeSecurityAssessment")
                      | select( ."resource-type" != "WaasCertificate") 
                      | select( ."resource-type" != "OnsTopic")   
                      | select( ."resource-type" != "IntegrationInstance") 
                      | select( ."resource-type" != "DataCatalog") 
                      | select( ."resource-type" != "TagDefault")  
                      | select( ."resource-type" != "LoadBalancer")   
                      | select( ."resource-type" != "PluggableDatabase")    
                      | select( ."resource-type" != "ContainerRepo")
                      | select( ."resource-type" != "Bastion")    
                      | {id:.identifier,resourceType:."resource-type"}' $SEARCH_OUT | jq -s '.' > $RESOURCES_JSON
    
    #3. opc next page is stored into a global var
    if [[ ! -s $SEARCH_OUT ]]
        then 
            OPC_NEXT_PAGE="null"
        else
            OPC_NEXT_PAGE=$( jq '."opc-next-page"' $SEARCH_OUT)
        fi
    #echo "find_resources_in_compartment end"
}

#find_and_tag_resources_in_compartment ocid1.compartment.oc1..aaaaaaaammgumtcs2c4opy5pynvxsr3qpvqtbve5fykcdobcracwg5yj2zmq Testing123 Oppy123 "Create Low code applications on OCI"
find_and_tag_resources_in_compartment(){
    if [ "$#" -ne 4 ]; then
        echo "Usage: find_and_tag_resources_in_compartment CompartmentID PartnerId OpportunityId Workload"
        echo $@
        echo $#
        return 1
    fi
    local COMPARTMENT_ID=$1
    local PARTNER_ID=$2
    local OPPY_ID=$3
    local WORKLOAD_NAME=$4
    local RESOURCES_JSON="resources_part.json"
    unset OPC_NEXT_PAGE
   
    echo ""
    echo "Finding and tagging resources in compartment $COMPARTMENT_ID"
    #we are cycling search and tag beacause tag can only process 100 resources at a time
    #so getting the list of all resources would not work
    #when there is no "opc-next-page" in find_resources_in_compartment, the value is set to null there
    while [[ $OPC_NEXT_PAGE != "null" ]]
    do
        find_resources_in_compartment $COMPARTMENT_ID $RESOURCES_JSON $OPC_NEXT_PAGE
        tag_resources $COMPARTMENT_ID $PARTNER_ID $OPPY_ID "$WORKLOAD_NAME" $RESOURCES_JSON
        #for testing
        #echo ""
        #OPC_NEXT_PAGE="null"
    done

    #2. find all subcompartments of this compartments and recursivelly call self for each sub
    find_subcompartments $COMPARTMENT_ID
    local SUBCOMPS=$(cat subcompartments.${COMPARTMENT_ID}.list)
    for SC in $SUBCOMPS
    do
        echo "next compartment: $SC"
        find_and_tag_resources_in_compartment $SC $PARTNER_ID $OPPY_ID "$WORKLOAD_NAME"
    done
}


find_subcompartments()
{
    local COMPARTMENT_ID=$1
    local JSON_OUT=subcompartments.$COMPARTMENT_ID.json
    local LIST_OUT=subcompartments.$COMPARTMENT_ID.list
    unset COMPARTMENTS_NEXT_PAGE
    [ -e $JSON_OUT ] && rm $JSON_OUT
    [ -e $LIST_OUT ] &&rm $LIST_OUT

    echo ""
    echo "Fetching subcompartments for compartment $COMPARTMENT_ID"
    echo ""
    echo "If there are many compartments and you are using passphrase protected keys, you will see multiple prompts"
    while [[ $COMPARTMENTS_NEXT_PAGE != "null" ]]
    do
        oci iam compartment list -c $COMPARTMENT_ID ${COMPARTMENTS_NEXT_PAGE:+--page} $COMPARTMENTS_NEXT_PAGE --access-level ACCESSIBLE > $JSON_OUT
        jq -r '.data[].id' $JSON_OUT >> $LIST_OUT
        #it seems we get empty file if there are no subcompartments, which breaks paging logic
        if [[ ! -s $JSON_OUT ]]
        then 
            COMPARTMENTS_NEXT_PAGE="null"
        else
            COMPARTMENTS_NEXT_PAGE=$( jq '."opc-next-page"' $JSON_OUT)
        fi
        
    done
}

clear_all_opn_tags()
{
    if [[ ! -f opn_tag_namespace.sh  ]]
    then
        echo "it seems the namespace has not been created through a script, can't proceed"
        return 1
    fi
    source opn_tag_namespace.sh 
    oci iam tag bulk-delete --tag-definition-ids \
    '[
        '\"${TAG_PARTNERID_OCID}\"',
        '\"${TAG_OPPYID_OCID}\"',
        '\"${TAG_WORKLOAD_OCID}\"'
     ]'
}
# opn_tagging
Community provided script for tagging OPN resources in OCI tenancy.

!WARNING!

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.


# Usage

1. Install the script in OCI shell or locally if you have OCI CLI setup.
2. Source it with ```source opn-tags.sh```

## To Create OPN Tags

Once sourced, use function ```create_opn_tag_namespace``` with no parameters.
This function will create the namespace and the 3 tags:
- PartnerID
- OpportunityID
- Workload

Note that Workload is a list. The source for the list is https://www.oracle.com/opn/secure/campaign/workload-search/index.html, but the script currently doesn't use it, so it could be out of date. Check it out and amend if required.

Function will also persist OCIDs into a file opn_tag_namespace.sh.

## To recursively search and tag resources

Once sourced and namespace has been created, use ```find_and_tag_resources_in_compartment <CompartmentId> <PartnerId> <OpportunityId> <Workload>```

CompartmentId - the topmost compartment to start with. If you have parallel topmost compartment, you will need to call the function for each of those.

PartnerId - Partner OPN ID.

OpportunityId - The opportunity ID aligned with the vendor. Talk to vendor's account manager or partner manager if you are not sure what it is.

Workload - One of the workloads from the [list](https://www.oracle.com/opn/secure/campaign/workload-search/index.html). **Make sure to enclose it in quotes**, e.g.: "Extend Apps with Digital Assistant/Chatbots". Without the quotes, each word is treated as parameter and it will fail.

## To delete opn namespace and related tags

Once sourced and namespace has been created, use ```delete_opn_tag_namespace``` to retire and delete tags.
Note: needs testing

# Issues

## Not all resources can be tagged

Not all resources can be tagged / OCI CLI throws an error when some types of resources are bulk tagged. It's not clear if the list of these is documented somewhere. In ```find_resources_in_compartment``` you will find resource types which we are filtering out.

If you get an error that a specific resource type can't be tagged, add a line for that type (and share your code). Simply run the script again, tagging can be applied multiple times with no ill effects.

## Tagging is performed in a bg job

The script only submits work requests. The actual tagging is done in background and it might take awhile before you see the tags applied.

## Your tenancy might get throttled

It's not clear what, but some operations might engage throttling on the tenancy and the operations will take longer to be completed. This seems to be more common when using the OCI console (e.g. deleting tag namespaces).


import azure.functions as func
import logging

app = func.FunctionApp()
logging.info('ERE')

@app.cosmos_db_trigger(arg_name="azcosmosdb", container_name="Resources",
                        database_name="AzureTRE", connection="cosmosnwsdedev_DOCUMENTDB", lease_container_name="leases", create_lease_container_if_not_exists=True)

def ws_cosmosdb_trigger(azcosmosdb: func.DocumentList):
    logging.info('Python CosmosDB triggered.')

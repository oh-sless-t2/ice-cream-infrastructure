/*
I'm leaving this module here as an anti-pattern reference, it is not good practice as connection strings should not be written to outputs.

This module demonstrates an interesting pattern, where the behaviour of ListConnectionString is;
"ListConnectionString requires a value that can be calculated at the start of the deployment"
However we need to delay the evaluation of ListConnectionString until after the resource is created in a module.
*/
param resourceId string
param nameOfSomethingToWaitFor string

var cosmosConnString = first(listConnectionStrings(resourceId, '2015-04-08').connectionStrings).connectionString

output ConnectionString string = cosmosConnString
output TheThingWeWaitedFor string = nameOfSomethingToWaitFor

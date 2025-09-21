import ballerina/http;
import ballerina/time;
import ballerina/log;

// In-memory database
map<Asset> assetDatabase = {};

// Service implementation
service /assets on new http:Listener(8080) {

    // Create a new asset
    resource function post .(@http:Payload Asset asset) returns http:Created|http:BadRequest|http:Conflict {
        if assetDatabase.hasKey(asset.assetTag) {
            return http:CONFLICT;
        }
        
        // Initialize empty maps if they're empty
        if asset.components.length() == 0 {
            asset.components = {};
        }
        if asset.schedules.length() == 0 {
            asset.schedules = {};
        }
        if asset.workOrders.length() == 0 {
            asset.workOrders = {};
        }
        
        assetDatabase[asset.assetTag] = asset;
        log:printInfo("Created asset: " + asset.assetTag);
        return http:CREATED;
    }

    // Get all assets
    resource function get .() returns Asset[] {
        return assetDatabase.toArray();
    }

    // Get asset by tag
    resource function get [string assetTag]() returns Asset|http:NotFound {
        if assetDatabase.hasKey(assetTag) {
            return assetDatabase.get(assetTag);
        }
        return http:NOT_FOUND;
    }

    // Update asset
    resource function put [string assetTag](@http:Payload Asset asset) returns http:Ok|http:NotFound|http:BadRequest {
        if !assetDatabase.hasKey(assetTag) {
            return http:NOT_FOUND;
        }
        
        // Ensure the assetTag matches
        asset.assetTag = assetTag;
        assetDatabase[assetTag] = asset;
        log:printInfo("Updated asset: " + assetTag);
        return http:OK;
    }

    // Delete asset
    resource function delete [string assetTag]() returns http:Ok|http:NotFound {
        if !assetDatabase.hasKey(assetTag) {
            return http:NOT_FOUND;
        }
        
        _ = assetDatabase.remove(assetTag);
        log:printInfo("Deleted asset: " + assetTag);
        return http:OK;
    }

    // Get assets by faculty
    resource function get faculty/[string facultyName]() returns Asset[] {
        Asset[] facultyAssets = [];
        foreach Asset asset in assetDatabase {
            if asset.faculty == facultyName {
                facultyAssets.push(asset);
            }
        }
        return facultyAssets;
    }

    // Get overdue assets (schedules past due date)
    resource function get overdue() returns Asset[] {
        Asset[] overdueAssets = [];
        string currentDate = time:utcToString(time:utcNow());
        
        foreach Asset asset in assetDatabase {
            boolean isOverdue = false;
            foreach Schedule schedule in asset.schedules {
                if schedule.nextDueDate < currentDate {
                    isOverdue = true;
                    break;
                }
            }
            if isOverdue {
                overdueAssets.push(asset);
            }
        }
        return overdueAssets;
    }

    // Component management
    // Add component to asset
    resource function post [string assetTag]/components(@http:Payload Component component) returns http:Created|http:NotFound {
        if !assetDatabase.hasKey(assetTag) {
            return http:NOT_FOUND;
        }
        
        Asset asset = assetDatabase.get(assetTag);
        asset.components[component.componentId] = component;
        assetDatabase[assetTag] = asset;
        log:printInfo("Added component " + component.componentId + " to asset " + assetTag);
        return http:CREATED;
    }

    // Get components of an asset
    resource function get [string assetTag]/components() returns Component[]|http:NotFound {
        if !assetDatabase.hasKey(assetTag) {
            return http:NOT_FOUND;
        }
        
        Asset asset = assetDatabase.get(assetTag);
        return asset.components.toArray();
    }

    // Delete component from asset
    resource function delete [string assetTag]/components/[string componentId]() returns http:Ok|http:NotFound {
        if !assetDatabase.hasKey(assetTag) {
            return http:NOT_FOUND;
        }
        
        Asset asset = assetDatabase.get(assetTag);
        if !asset.components.hasKey(componentId) {
            return http:NOT_FOUND;
        }
        
        _ = asset.components.remove(componentId);
        assetDatabase[assetTag] = asset;
        log:printInfo("Removed component " + componentId + " from asset " + assetTag);
        return http:OK;
    }

    // Schedule management
    // Add schedule to asset
    resource function post [string assetTag]/schedules(@http:Payload Schedule schedule) returns http:Created|http:NotFound {
        if !assetDatabase.hasKey(assetTag) {
            return http:NOT_FOUND;
        }
        
        Asset asset = assetDatabase.get(assetTag);
        asset.schedules[schedule.scheduleId] = schedule;
        assetDatabase[assetTag] = asset;
        log:printInfo("Added schedule " + schedule.scheduleId + " to asset " + assetTag);
        return http:CREATED;
    }

    // Get schedules of an asset
    resource function get [string assetTag]/schedules() returns Schedule[]|http:NotFound {
        if !assetDatabase.hasKey(assetTag) {
            return http:NOT_FOUND;
        }
        
        Asset asset = assetDatabase.get(assetTag);
        return asset.schedules.toArray();
    }

    // Delete schedule from asset
    resource function delete [string assetTag]/schedules/[string scheduleId]() returns http:Ok|http:NotFound {
        if !assetDatabase.hasKey(assetTag) {
            return http:NOT_FOUND;
        }
        
        Asset asset = assetDatabase.get(assetTag);
        if !asset.schedules.hasKey(scheduleId) {
            return http:NOT_FOUND;
        }
        
        _ = asset.schedules.remove(scheduleId);
        assetDatabase[assetTag] = asset;
        log:printInfo("Removed schedule " + scheduleId + " from asset " + assetTag);
        return http:OK;
    }

    // Work Order management
    // Create work order for asset
    resource function post [string assetTag]/workorders(@http:Payload WorkOrder workOrder) returns http:Created|http:NotFound {
        if !assetDatabase.hasKey(assetTag) {
            return http:NOT_FOUND;
        }
        
        Asset asset = assetDatabase.get(assetTag);
        asset.workOrders[workOrder.workOrderId] = workOrder;
        assetDatabase[assetTag] = asset;
        log:printInfo("Created work order " + workOrder.workOrderId + " for asset " + assetTag);
        return http:CREATED;
    }

    // Get work orders of an asset
    resource function get [string assetTag]/workorders() returns WorkOrder[]|http:NotFound {
        if !assetDatabase.hasKey(assetTag) {
            return http:NOT_FOUND;
        }
        
        Asset asset = assetDatabase.get(assetTag);
        return asset.workOrders.toArray();
    }

    // Update work order status
    resource function put [string assetTag]/workorders/[string workOrderId](@http:Payload WorkOrder workOrder) returns http:Ok|http:NotFound {
        if !assetDatabase.hasKey(assetTag) {
            return http:NOT_FOUND;
        }
        
        Asset asset = assetDatabase.get(assetTag);
        if !asset.workOrders.hasKey(workOrderId) {
            return http:NOT_FOUND;
        }
        
        workOrder.workOrderId = workOrderId;
        asset.workOrders[workOrderId] = workOrder;
        assetDatabase[assetTag] = asset;
        log:printInfo("Updated work order " + workOrderId + " for asset " + assetTag);
        return http:OK;
    }

    // Task management within work orders
    // Add task to work order
    resource function post [string assetTag]/workorders/[string workOrderId]/tasks(@http:Payload Task task) returns http:Created|http:NotFound {
        if !assetDatabase.hasKey(assetTag) {
            return http:NOT_FOUND;
        }
        
        Asset asset = assetDatabase.get(assetTag);
        if !asset.workOrders.hasKey(workOrderId) {
            return http:NOT_FOUND;
        }
        
        WorkOrder workOrder = asset.workOrders.get(workOrderId);
        workOrder.tasks[task.taskId] = task;
        asset.workOrders[workOrderId] = workOrder;
        assetDatabase[assetTag] = asset;
        log:printInfo("Added task " + task.taskId + " to work order " + workOrderId);
        return http:CREATED;
    }

    // Get tasks of a work order
    resource function get [string assetTag]/workorders/[string workOrderId]/tasks() returns Task[]|http:NotFound {
        if !assetDatabase.hasKey(assetTag) {
            return http:NOT_FOUND;
        }
        
        Asset asset = assetDatabase.get(assetTag);
        if !asset.workOrders.hasKey(workOrderId) {
            return http:NOT_FOUND;
        }
        
        WorkOrder workOrder = asset.workOrders.get(workOrderId);
        return workOrder.tasks.toArray();
    }

    // Delete task from work order
    resource function delete [string assetTag]/workorders/[string workOrderId]/tasks/[string taskId]() returns http:Ok|http:NotFound {
        if !assetDatabase.hasKey(assetTag) {
            return http:NOT_FOUND;
        }
        
        Asset asset = assetDatabase.get(assetTag);
        if !asset.workOrders.hasKey(workOrderId) {
            return http:NOT_FOUND;
        }
        
        WorkOrder workOrder = asset.workOrders.get(workOrderId);
        if !workOrder.tasks.hasKey(taskId) {
            return http:NOT_FOUND;
        }
        
        _ = workOrder.tasks.remove(taskId);
        asset.workOrders[workOrderId] = workOrder;
        assetDatabase[assetTag] = asset;
        log:printInfo("Removed task " + taskId + " from work order " + workOrderId);
        return http:OK;
    }
}
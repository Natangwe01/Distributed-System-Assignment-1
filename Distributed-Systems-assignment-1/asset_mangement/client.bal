import ballerina/http;
import ballerina/io;

// Data structures (same as service)
type AssetStatus "ACTIVE"|"UNDER_REPAIR"|"DISPOSED";

type Component record {
    string componentId;
    string name;
    string description?;
    string status?;
};

type Schedule record {
    string scheduleId;
    string description;
    string frequency;
    string nextDueDate;
    string lastServiceDate?;
};

type Task record {
    string taskId;
    string description;
    string status;
    string assignedTo?;
};

type WorkOrder record {
    string workOrderId;
    string description;
    string status;
    string createdDate;
    string? completedDate;
    map<Task> tasks;
};

type Asset record {
    string assetTag;
    string name;
    string faculty;
    string department;
    AssetStatus status;
    string acquiredDate;
    map<Component> components;
    map<Schedule> schedules;
    map<WorkOrder> workOrders;
};

public function main() returns error? {
    // Create HTTP client
    http:Client assetClient = check new("http://localhost:8080");
    
    io:println("=== NUST Asset Management System Demo ===\n");
    
    // 1. Create assets
    io:println("1. Creating Assets:");
    
    Asset printer = {
        assetTag: "EQ-001",
        name: "3D Printer",
        faculty: "Computing & Informatics",
        department: "Software Engineering",
        status: "ACTIVE",
        acquiredDate: "2024-03-10",
        components: {},
        schedules: {},
        workOrders: {}
    };
    
    Asset server = {
        assetTag: "IT-001",
        name: "Dell Server",
        faculty: "Computing & Informatics",
        department: "Information Technology",
        status: "ACTIVE",
        acquiredDate: "2023-01-15",
        components: {},
        schedules: {},
        workOrders: {}
    };
    
    Asset microscope = {
        assetTag: "SC-001",
        name: "Digital Microscope",
        faculty: "Science",
        department: "Biology",
        status: "ACTIVE",
        acquiredDate: "2023-06-20",
        components: {},
        schedules: {},
        workOrders: {}
    };
    
    // Create assets
    http:Response response1 = check assetClient->post("/assets", printer);
    io:println("Created printer: " + response1.statusCode.toString());
    
    http:Response response2 = check assetClient->post("/assets", server);
    io:println("Created server: " + response2.statusCode.toString());
    
    http:Response response3 = check assetClient->post("/assets", microscope);
    io:println("Created microscope: " + response3.statusCode.toString());
    
    // 2. View all assets
    io:println("\n2. Viewing All Assets:");
    Asset[] allAssets = check assetClient->get("/assets");
    foreach Asset asset in allAssets {
        io:println("- " + asset.assetTag + ": " + asset.name + " (" + asset.faculty + ")");
    }
    
    // 3. Update an asset
    io:println("\n3. Updating Asset Status:");
    server.status = "UNDER_REPAIR";
    http:Response updateResponse = check assetClient->put("/assets/" + server.assetTag, server);
    io:println("Updated server status: " + updateResponse.statusCode.toString());
    
    // 4. View assets by faculty
    io:println("\n4. Viewing Assets by Faculty (Computing & Informatics):");
    Asset[] facultyAssets = check assetClient->get("/assets/faculty/Computing%20%26%20Informatics");
    foreach Asset asset in facultyAssets {
        io:println("- " + asset.assetTag + ": " + asset.name + " (Status: " + asset.status + ")");
    }
    
    // 5. Add components
    io:println("\n5. Adding Components:");
    
    Component printerMotor = {
        componentId: "COMP-001",
        name: "Stepper Motor",
        description: "X-axis stepper motor",
        status: "ACTIVE"
    };
    
    Component serverHDD = {
        componentId: "COMP-002",
        name: "Hard Drive",
        description: "2TB SATA Hard Drive",
        status: "ACTIVE"
    };
    
    http:Response compResponse1 = check assetClient->post("/assets/EQ-001/components", printerMotor);
    io:println("Added printer motor: " + compResponse1.statusCode.toString());
    
    http:Response compResponse2 = check assetClient->post("/assets/IT-001/components", serverHDD);
    io:println("Added server HDD: " + compResponse2.statusCode.toString());
    
    // 6. Add maintenance schedules
    io:println("\n6. Adding Maintenance Schedules:");
    
    Schedule printerMaintenance = {
        scheduleId: "SCH-001",
        description: "Quarterly printer maintenance",
        frequency: "QUARTERLY",
        nextDueDate: "2024-12-15",
        lastServiceDate: "2024-09-15"
    };
    
    Schedule serverMaintenance = {
        scheduleId: "SCH-002",
        description: "Monthly server backup verification",
        frequency: "MONTHLY",
        nextDueDate: "2024-09-01", // This will be overdue
        lastServiceDate: "2024-08-01"
    };
    
    http:Response schedResponse1 = check assetClient->post("/assets/EQ-001/schedules", printerMaintenance);
    io:println("Added printer maintenance schedule: " + schedResponse1.statusCode.toString());
    
    http:Response schedResponse2 = check assetClient->post("/assets/IT-001/schedules", serverMaintenance);
    io:println("Added server maintenance schedule: " + schedResponse2.statusCode.toString());
    
    // 7. Check for overdue assets
    io:println("\n7. Checking for Overdue Assets:");
    Asset[] overdueAssets = check assetClient->get("/assets/overdue");
    if overdueAssets.length() > 0 {
        io:println("Found " + overdueAssets.length().toString() + " overdue asset(s):");
        foreach Asset asset in overdueAssets {
            io:println("- " + asset.assetTag + ": " + asset.name);
            foreach Schedule schedule in asset.schedules {
                if schedule.nextDueDate < "2024-09-21" {
                    io:println("  Overdue schedule: " + schedule.description + " (Due: " + schedule.nextDueDate + ")");
                }
            }
        }
    } else {
        io:println("No overdue assets found.");
    }
    
    // 8. Create work orders
    io:println("\n8. Creating Work Orders:");
    
    WorkOrder serverRepair = {
        workOrderId: "WO-001",
        description: "Server hardware diagnostics and repair",
        status: "OPEN",
        createdDate: "2024-09-21",
        completedDate: (),
        tasks: {}
    };
    
    http:Response woResponse = check assetClient->post("/assets/IT-001/workorders", serverRepair);
    io:println("Created work order: " + woResponse.statusCode.toString());
    
    // 9. Add tasks to work order
    io:println("\n9. Adding Tasks to Work Order:");
    
    Task diagnosisTask = {
        taskId: "TASK-001",
        description: "Run hardware diagnostics",
        status: "PENDING",
        assignedTo: "John Doe"
    };
    
    Task repairTask = {
        taskId: "TASK-002",
        description: "Replace faulty component",
        status: "PENDING",
        assignedTo: "Jane Smith"
    };
    
    http:Response taskResponse1 = check assetClient->post("/assets/IT-001/workorders/WO-001/tasks", diagnosisTask);
    io:println("Added diagnosis task: " + taskResponse1.statusCode.toString());
    
    http:Response taskResponse2 = check assetClient->post("/assets/IT-001/workorders/WO-001/tasks", repairTask);
    io:println("Added repair task: " + taskResponse2.statusCode.toString());
    
    // 10. Retrieve specific asset details
    io:println("\n10. Retrieving Detailed Asset Information:");
    Asset detailedServer = check assetClient->get("/assets/IT-001");
    io:println("Asset: " + detailedServer.name);
    io:println("Status: " + detailedServer.status);
    io:println("Components: " + detailedServer.components.length().toString());
    io:println("Schedules: " + detailedServer.schedules.length().toString());
    io:println("Work Orders: " + detailedServer.workOrders.length().toString());
    
    // 11. Demonstrate component retrieval
    io:println("\n11. Retrieving Components:");
    Component[] components = check assetClient->get("/assets/IT-001/components");
    foreach Component comp in components {
        io:println("- " + comp.componentId + ": " + comp.name + " (" + (comp.status ?: "N/A") + ")");
    }
    
    // 12. Demonstrate schedule retrieval
    io:println("\n12. Retrieving Schedules:");
    Schedule[] schedules = check assetClient->get("/assets/IT-001/schedules");
    foreach Schedule sched in schedules {
        io:println("- " + sched.scheduleId + ": " + sched.description + " (Due: " + sched.nextDueDate + ")");
    }
    
    // 13. Demonstrate task retrieval
    io:println("\n13. Retrieving Work Order Tasks:");
    Task[] tasks = check assetClient->get("/assets/IT-001/workorders/WO-001/tasks");
    foreach Task task in tasks {
        io:println("- " + task.taskId + ": " + task.description + " (" + task.status + ")");
    }
    
    // 14. Update work order status
    io:println("\n14. Updating Work Order Status:");
    serverRepair.status = "IN_PROGRESS";
    http:Response woUpdateResponse = check assetClient->put("/assets/IT-001/workorders/WO-001", serverRepair);
    io:println("Updated work order status: " + woUpdateResponse.statusCode.toString());
    
    // 15. Remove a component (demonstration of delete)
    io:println("\n15. Removing Component:");
    http:Response deleteCompResponse = check assetClient->delete("/assets/EQ-001/components/COMP-001");
    io:println("Removed printer motor: " + deleteCompResponse.statusCode.toString());
    
    io:println("\n=== Demo Completed Successfully! ===");
}
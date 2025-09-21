import ballerina/grpc;
import ballerina/io;
import ballerina/log;

// Import the same types as server
public type CarStatus "AVAILABLE"|"UNAVAILABLE"|"RENTED"|"MAINTENANCE";
public type UserRole "CUSTOMER"|"ADMIN";
public type ReservationStatus "PENDING"|"CONFIRMED"|"CANCELLED"|"COMPLETED";

public type Car record {
    string plate;
    string make;
    string model;
    int year;
    float daily_price;
    int mileage;
    CarStatus status;
    string description;
    string color;
    string category;
};

public type User record {
    string user_id;
    string name;
    string email;
    string phone;
    UserRole role;
    string address;
    string license_number;
};

// Client for interacting with Car Rental Service
CarRentalServiceClient carRentalClient = check new("http://localhost:9090");

public function main() returns error? {
    io:println("=== Car Rental System gRPC Client Demo ===\n");
    
    // Demo scenario
    check demonstrateCarRentalSystem();
    
    io:println("\n=== Demo Completed Successfully! ===");
}

function demonstrateCarRentalSystem() returns error? {
    
    // 1. Create users (streaming)
    io:println("1. Creating Users (Admin and Customers):");
    check createUsers();
    
    // 2. Add cars (Admin operation)
    io:println("\n2. Adding Cars to Inventory (Admin):");
    check addSampleCars();
    
    // 3. List available cars (Customer operation)
    io:println("\n3. Listing Available Cars (Customer):");
    check listAvailableCars("customer1");
    
    // 4. Search for specific car
    io:println("\n4. Searching for Specific Car:");
    check searchSpecificCar("customer1", "ABC123");
    
    // 5. Add cars to cart
    io:println("\n5. Adding Cars to Cart:");
    check addToCart("customer1", "ABC123", "2024-10-01", "2024-10-05");
    check addToCart("customer1", "XYZ789", "2024-10-10", "2024-10-12");
    
    // 6. View cart
    io:println("\n6. Viewing Cart Contents:");
    check viewCart("customer1");
    
    // 7. Place reservation
    io:println("\n7. Placing Reservation:");
    check placeReservation("customer1");
    
    // 8. Update car details (Admin operation)
    io:println("\n8. Updating Car Details (Admin):");
    check updateCarDetails("admin1", "ABC123");
    
    // 9. List all reservations (Admin operation)
    io:println("\n9. Listing All Reservations (Admin):");
    check listAllReservations("admin1");
    
    // 10. Remove car (Admin operation)
    io:println("\n10. Removing Car from Inventory (Admin):");
    check removeCar("admin1", "DEF456");
}

function createUsers() returns error? {
    User[] users = [
        {
            user_id: "admin1",
            name: "John Admin",
            email: "admin@carrental.com",
            phone: "+264-81-1234567",
            role: "ADMIN",
            address: "123 Admin Street, Windhoek",
            license_number: "ADM001"
        },
        {
            user_id: "customer1",
            name: "Alice Customer",
            email: "alice@example.com",
            phone: "+264-81-2345678",
            role: "CUSTOMER",
            address: "456 Customer Ave, Windhoek",
            license_number: "DL123456"
        },
        {
            user_id: "customer2",
            name: "Bob Smith",
            email: "bob@example.com",
            phone: "+264-81-3456789",
            role: "CUSTOMER",
            address: "789 Smith Road, Windhoek",
            license_number: "DL789012"
        }
    ];
    
    CreateUsersStreamingClient streamingClient = check carRentalClient->CreateUsers();
    
    foreach User user in users {
        check streamingClient.sendUser(user);
        io:println("- Sent user: " + user.name + " (" + user.role + ")");
    }
    
    CreateUsersResponse response = check streamingClient.complete();
    io:println("Result: " + response.message);
    
    return;
}

function addSampleCars() returns error? {
    Car[] cars = [
        {
            plate: "ABC123",
            make: "Toyota",
            model: "Camry",
            year: 2023,
            daily_price: 45.00,
            mileage: 15000,
            status: "AVAILABLE",
            description: "Reliable sedan with excellent fuel economy",
            color: "Silver",
            category: "Sedan"
        },
        {
            plate: "XYZ789",
            make: "Honda",
            model: "CR-V",
            year: 2022,
            daily_price: 55.00,
            mileage: 22000,
            status: "AVAILABLE",
            description: "Spacious SUV perfect for family trips",
            color: "Blue",
            category: "SUV"
        },
        {
            plate: "DEF456",
            make: "BMW",
            model: "3 Series",
            year: 2024,
            daily_price: 75.00,
            mileage: 5000,
            status: "AVAILABLE",
            description: "Luxury sedan with premium features",
            color: "Black",
            category: "Luxury"
        },
        {
            plate: "GHI101",
            make: "Ford",
            model: "Mustang",
            year: 2023,
            daily_price: 85.00,
            mileage: 8000,
            status: "MAINTENANCE",
            description: "Sports car for enthusiasts",
            color: "Red",
            category: "Sports"
        }
    ];
    
    foreach Car car in cars {
        AddCarResponse response = check carRentalClient->AddCar(car);
        string status = response.success ? "✓" : "✗";
        io:println("- " + status + " " + car.make + " " + car.model + " (" + car.plate + "): " + response.message);
    }
    
    return;
}

function listAvailableCars(string customerId) returns error? {
    ListCarsRequest request = {
        customer_id: customerId,
        search_text: (),
        year_filter: (),
        max_price: (),
        category_filter: ()
    };
    
    stream<Car, grpc:Error?> carStream = check carRentalClient->ListAvailableCars(request);
    
    io:println("Available cars:");
    error? e = carStream.forEach(function(Car car) {
        io:println("- " + car.plate + ": " + car.make + " " + car.model + " (" + car.year.toString() + 
                  ") - $" + car.daily_price.toString() + "/day [" + car.status + "]");
    });
    
    if e is error {
        log:printError("Error listing cars", e);
    }
    
    return;
}

function searchSpecificCar(string customerId, string plate) returns error? {
    SearchCarRequest request = {
        plate: plate,
        customer_id: customerId
    };
    
    SearchCarResponse response = check carRentalClient->SearchCar(request);
    
    if response.found {
        Car car = <Car>response.car;
        io:println("Found car " + plate + ": " + car.make + " " + car.model);
        io:println("Status: " + response.message);
        io:println("Daily Rate: $" + car.daily_price.toString());
        io:println("Category: " + car.category);
    } else {
        io:println("Car " + plate + " not found");
    }
    
    return;
}

function addToCart(string customerId, string plate, string startDate, string endDate) returns error? {
    AddToCartRequest request = {
        customer_id: customerId,
        plate: plate,
        start_date: startDate,
        end_date: endDate
    };
    
    AddToCartResponse response = check carRentalClient->AddToCart(request);
    
    string status = response.success ? "✓" : "✗";
    io:println("- " + status + " Adding " + plate + " (" + startDate + " to " + endDate + "): " + response.message);
    
    if response.success && response.added_item is CartItem {
        CartItem item = <CartItem>response.added_item;
        io:println("  Total price: $" + item.total_price.toString() + " for " + item.days.toString() + " days");
        io:println("  Cart now has " + response.cart_items_count.toString() + " items");
    }
    
    return;
}

function viewCart(string customerId) returns error? {
    GetCartRequest request = {
        customer_id: customerId
    };
    
    CartResponse response = check carRentalClient->GetCart(request);
    
    io:println("Cart Contents (" + response.total_items.toString() + " items):");
    
    foreach CartItem item in response.items {
        io:println("- " + item.car_details.make + " " + item.car_details.model + " (" + item.plate + ")");
        io:println("  Dates: " + item.start_date + " to " + item.end_date + " (" + item.days.toString() + " days)");
        io:println("  Price: $" + item.total_price.toString());
    }
    
    io:println("Total Amount: $" + response.total_amount.toString());
    
    return;
}

function placeReservation(string customerId) returns error? {
    PlaceReservationRequest request = {
        customer_id: customerId
    };
    
    PlaceReservationResponse response = check carRentalClient->PlaceReservation(request);
    
    string status = response.success ? "✓" : "✗";
    io:println(status + " " + response.message);
    
    if response.success {
        io:println("Reservations created:");
        foreach Reservation reservation in response.reservations {
            io:println("- Reservation ID: " + reservation.reservation_id);
            io:println("  Car: " + reservation.car_details.make + " " + reservation.car_details.model + 
                      " (" + reservation.plate + ")");
            io:println("  Dates: " + reservation.start_date + " to " + reservation.end_date);
            io:println("  Total: $" + reservation.total_price.toString());
            io:println("  Status: " + reservation.status);
        }
        io:println("Total Amount: $" + response.total_amount.toString());
    }
    
    return;
}

function updateCarDetails(string adminId, string plate) returns error? {
    // First get the current car details
    Car updatedCar = {
        plate: plate,
        make: "Toyota",
        model: "Camry",
        year: 2023,
        daily_price: 50.00, // Updated price
        mileage: 15500, // Updated mileage
        status: "AVAILABLE",
        description: "Reliable sedan with excellent fuel economy - Recently serviced",
        color: "Silver",
        category: "Sedan"
    };
    
    UpdateCarRequest request = {
        plate: plate,
        updated_car: updatedCar
    };
    
    UpdateCarResponse response = check carRentalClient->UpdateCar(request);
    
    string status = response.success ? "✓" : "✗";
    io:println(status + " " + response.message);
    
    if response.success {
        Car car = response.updated_car;
        io:println("Updated car details:");
        io:println("- Daily price: $" + car.daily_price.toString());
        io:println("- Mileage: " + car.mileage.toString());
        io:println("- Description: " + car.description);
    }
    
    return;
}

function listAllReservations(string adminId) returns error? {
    ListReservationsRequest request = {
        admin_id: adminId,
        status_filter: ()
    };
    
    stream<Reservation, grpc:Error?> reservationStream = check carRentalClient->ListAllReservations(request);
    
    io:println("All Reservations:");
    int count = 0;
    
    error? e = reservationStream.forEach(function(Reservation reservation) {
        count += 1;
        io:println("- Reservation #" + count.toString() + ":");
        io:println("  ID: " + reservation.reservation_id);
        io:println("  Customer: " + reservation.customer_details.name + " (" + reservation.customer_id + ")");
        io:println("  Car: " + reservation.car_details.make + " " + reservation.car_details.model + 
                  " (" + reservation.plate + ")");
        io:println("  Dates: " + reservation.start_date + " to " + reservation.end_date);
        io:println("  Status: " + reservation.status);
        io:println("  Amount: $" + reservation.total_price.toString());
        io:println("  Created: " + reservation.created_at);
        io:println("");
    });
    
    if e is error {
        log:printError("Error listing reservations", e);
    } else {
        io:println("Total reservations: " + count.toString());
    }
    
    return;
}

function removeCar(string adminId, string plate) returns error? {
    RemoveCarRequest request = {
        plate: plate,
        admin_id: adminId
    };
    
    CarListResponse response = check carRentalClient->RemoveCar(request);
    
    io:println("✓ Car " + plate + " removed from inventory");
    io:println("Updated car inventory (" + response.total_count.toString() + " cars):");
    
    foreach Car car in response.cars {
        io:println("- " + car.plate + ": " + car.make + " " + car.model + " [" + car.status + "]");
    }
    
    return;
}

// Additional client types (would normally be generated from protobuf)

public type AddCarResponse record {
    boolean success;
    string message;
    string car_id;
};

public type CreateUsersResponse record {
    boolean success;
    string message;
    int users_created;
};

public type UpdateCarRequest record {
    string plate;
    Car updated_car;
};

public type UpdateCarResponse record {
    boolean success;
    string message;
    Car updated_car;
};

public type RemoveCarRequest record {
    string plate;
    string admin_id;
};

public type CarListResponse record {
    Car[] cars;
    int total_count;
};

public type ListReservationsRequest record {
    string admin_id;
    ReservationStatus? status_filter;
};

public type ListCarsRequest record {
    string customer_id;
    string? search_text;
    int? year_filter;
    float? max_price;
    string? category_filter;
};

public type SearchCarRequest record {
    string plate;
    string customer_id;
};

public type SearchCarResponse record {
    boolean found;
    boolean available;
    Car? car;
    string message;
};

public type AddToCartRequest record {
    string customer_id;
    string plate;
    string start_date;
    string end_date;
};

public type AddToCartResponse record {
    boolean success;
    string message;
    CartItem? added_item;
    int cart_items_count;
};

public type CartItem record {
    string plate;
    string start_date;
    string end_date;
    int days;
    float total_price;
    Car car_details;
};

public type Reservation record {
    string reservation_id;
    string customer_id;
    string plate;
    string start_date;
    string end_date;
    int days;
    float total_price;
    ReservationStatus status;
    string created_at;
    Car car_details;
    User customer_details;
};

public type PlaceReservationRequest record {
    string customer_id;
};

public type PlaceReservationResponse record {
    boolean success;
    string message;
    Reservation[] reservations;
    float total_amount;
};

public type GetCartRequest record {
    string customer_id;
};

public type CartResponse record {
    CartItem[] items;
    float total_amount;
    int total_items;
};

public type ClearCartRequest record {
    string customer_id;
};

public type ClearCartResponse record {
    boolean success;
    string message;
};

// Client stub (would normally be generated)
public client class CarRentalServiceClient {
    private grpc:Client grpcClient;

    public function init(string url, grpc:ClientConfiguration? config = ()) returns grpc:Error? {
        grpc:ClientConfiguration actualConfig = config is grpc:ClientConfiguration ? config : {};
        self.grpcClient = check new (url, actualConfig);
    }

    remote function AddCar(Car req) returns AddCarResponse|grpc:Error {
        map<string|string[]> headers = {};
        var payload = check self.grpcClient->executeSimpleRPC("CarRentalService/AddCar", req, headers);
        [anydata, map<string|string[]>] [result, _] = payload;
        return <AddCarResponse>result;
    }

    remote function CreateUsers() returns CreateUsersStreamingClient|grpc:Error {
        grpc:StreamingClient sClient = check self.grpcClient->executeClientStreaming("CarRentalService/CreateUsers");
        return new CreateUsersStreamingClient(sClient);
    }

    remote function UpdateCar(UpdateCarRequest req) returns UpdateCarResponse|grpc:Error {
        map<string|string[]> headers = {};
        var payload = check self.grpcClient->executeSimpleRPC("CarRentalService/UpdateCar", req, headers);
        [anydata, map<string|string[]>] [result, _] = payload;
        return <UpdateCarResponse>result;
    }

    remote function RemoveCar(RemoveCarRequest req) returns CarListResponse|grpc:Error {
        map<string|string[]> headers = {};
        var payload = check self.grpcClient->executeSimpleRPC("CarRentalService/RemoveCar", req, headers);
        [anydata, map<string|string[]>] [result, _] = payload;
        return <CarListResponse>result;
    }

    remote function ListAllReservations(ListReservationsRequest req) returns stream<Reservation, grpc:Error?>|grpc:Error {
        map<string|string[]> headers = {};
        var payload = check self.grpcClient->executeServerStreaming("CarRentalService/ListAllReservations", req, headers);
        [stream<anydata, grpc:Error?>, map<string|string[]>] [result, _] = payload;
        ReservationStream reservationStream = new ReservationStream(result);
        return new stream<Reservation, grpc:Error?>(reservationStream);
    }

    remote function ListAvailableCars(ListCarsRequest req) returns stream<Car, grpc:Error?>|grpc:Error {
        map<string|string[]> headers = {};
        var payload = check self.grpcClient->executeServerStreaming("CarRentalService/ListAvailableCars", req, headers);
        [stream<anydata, grpc:Error?>, map<string|string[]>] [result, _] = payload;
        CarStream carStream = new CarStream(result);
        return new stream<Car, grpc:Error?>(carStream);
    }

    remote function SearchCar(SearchCarRequest req) returns SearchCarResponse|grpc:Error {
        map<string|string[]> headers = {};
        var payload = check self.grpcClient->executeSimpleRPC("CarRentalService/SearchCar", req, headers);
        [anydata, map<string|string[]>] [result, _] = payload;
        return <SearchCarResponse>result;
    }

    remote function AddToCart(AddToCartRequest req) returns AddToCartResponse|grpc:Error {
        map<string|string[]> headers = {};
        var payload = check self.grpcClient->executeSimpleRPC("CarRentalService/AddToCart", req, headers);
        [anydata, map<string|string[]>] [result, _] = payload;
        return <AddToCartResponse>result;
    }

    remote function PlaceReservation(PlaceReservationRequest req) returns PlaceReservationResponse|grpc:Error {
        map<string|string[]> headers = {};
        var payload = check self.grpcClient->executeSimpleRPC("CarRentalService/PlaceReservation", req, headers);
        [anydata, map<string|string[]>] [result, _] = payload;
        return <PlaceReservationResponse>result;
    }

    remote function GetCart(GetCartRequest req) returns CartResponse|grpc:Error {
        map<string|string[]> headers = {};
        var payload = check self.grpcClient->executeSimpleRPC("CarRentalService/GetCart", req, headers);
        [anydata, map<string|string[]>] [result, _] = payload;
        return <CartResponse>result;
    }

    remote function ClearCart(ClearCartRequest req) returns ClearCartResponse|grpc:Error {
        map<string|string[]> headers = {};
        var payload = check self.grpcClient->executeSimpleRPC("CarRentalService/ClearCart", req, headers);
        [anydata, map<string|string[]>] [result, _] = payload;
        return <ClearCartResponse>result;
    }
}

// Streaming clients
public class CreateUsersStreamingClient {
    private grpc:StreamingClient sClient;

    isolated function init(grpc:StreamingClient sClient) {
        self.sClient = sClient;
    }

    isolated function sendUser(User message) returns grpc:Error? {
        return self.sClient->send(message);
    }

    isolated function complete() returns CreateUsersResponse|grpc:Error {
        var result = self.sClient->complete();
        if result is error {
            return error grpc:Error(result.message());
        }
        if result is () {
            return error grpc:Error("No response received from server");
        }
        return <CreateUsersResponse>result;
    }
}

// Stream iterators
class CarStream {
    private stream<anydata, grpc:Error?> anydataStream;

    isolated function init(stream<anydata, grpc:Error?> anydataStream) {
        self.anydataStream = anydataStream;
    }

    public isolated function next() returns record {|Car value;|}|grpc:Error? {
        var streamValue = self.anydataStream.next();
        if streamValue is () {
            return streamValue;
        } else if streamValue is grpc:Error {
            return streamValue;
        } else {
            record {|Car value;|} nextRecord = {value: <Car>streamValue.value};
            return nextRecord;
        }
    }
}

class ReservationStream {
    private stream<anydata, grpc:Error?> anydataStream;

    isolated function init(stream<anydata, grpc:Error?> anydataStream) {
        self.anydataStream = anydataStream;
    }

    public isolated function next() returns record {|Reservation value;|}|grpc:Error? {
        var streamValue = self.anydataStream.next();
        if streamValue is () {
            return streamValue;
        } else if streamValue is grpc:Error {
            return streamValue;
        } else {
            record {|Reservation value;|} nextRecord = {value: <Reservation>streamValue.value};
            return nextRecord;
        }
    }
}
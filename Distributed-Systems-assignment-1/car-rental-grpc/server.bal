import ballerina/grpc;
import ballerina/log;
import ballerina/time;
import ballerina/uuid;

// Type definitions based on protobuf
// Type definitions based on protobuf
// (REMOVED DUPLICATE TYPE DEFINITIONS HERE. ENSURE THESE TYPES ARE ONLY DEFINED ONCE IN YOUR PROJECT.)
// If you need these types, keep them in a single file only, and remove all other duplicate definitions from other files in your project.
    boolean success;
    string message;


// In-memory storage
map<Car> carInventory = {};
map<User> users = {};
map<CartItem[]> customerCarts = {};
map<Reservation> reservations = {};

// Utility functions
function calculateDays(string startDate, string endDate) returns int|error {
    // Simple day calculation (assuming YYYY-MM-DD format)
    time:Utc startTime = check time:utcFromString(startDate + "T00:00:00.000Z");
    time:Utc endTime = check time:utcFromString(endDate + "T00:00:00.000Z");
    
    time:Seconds diff = time:utcDiffSeconds(endTime, startTime);
    return <int>(diff / (24 * 3600));
}

function isCarAvailable(string plate, string startDate, string endDate) returns boolean {
    // Check if car exists and is available
    if !carInventory.hasKey(plate) {
        return false;
    }
    
    Car car = carInventory.get(plate);
    if car.status != "AVAILABLE" {
        return false;
    }
    
    // Check for overlapping reservations
    foreach Reservation reservation in reservations {
        if reservation.plate == plate && reservation.status != "CANCELLED" {
            // Check for date overlap
            if !(endDate <= reservation.start_date || startDate >= reservation.end_date) {
                return false;
            }
        }
    }
    
    return true;
}

function isValidUser(string userId, UserRole requiredRole) returns boolean {
    if !users.hasKey(userId) {
        return false;
    }
    
    User user = users.get(userId);
    return user.role == requiredRole;
}

// gRPC Service Implementation
@grpc:Descriptor {value: CAR_RENTAL_DESC}
service "CarRentalService" on new grpc:Listener(9090) {

    // Admin operation: Add a new car
    remote function AddCar(Car car) returns AddCarResponse|error {
        log:printInfo("Adding car: " + car.plate);
        
        if carInventory.hasKey(car.plate) {
            return {
                success: false,
                message: "Car with plate " + car.plate + " already exists",
                car_id: ""
            };
        }
        
        carInventory[car.plate] = car;
        
        return {
            success: true,
            message: "Car added successfully",
            car_id: car.plate
        };
    }

    // Admin operation: Create multiple users (streaming)
    remote function CreateUsers(stream<User, grpc:Error?> clientStream) returns CreateUsersResponse|error {
        log:printInfo("Creating users from stream");
        
        int userCount = 0;
        
        error? e = clientStream.forEach(function(User user) {
            users[user.user_id] = user;
            customerCarts[user.user_id] = []; // Initialize empty cart
            userCount += 1;
            log:printInfo("Created user: " + user.name + " (" + user.role + ")");
        });
        
        if e is error {
            log:printError("Error processing user stream", e);
            return {
                success: false,
                message: "Error processing users: " + e.message(),
                users_created: userCount
            };
        }
        
        return {
            success: true,
            message: "Successfully created " + userCount.toString() + " users",
            users_created: userCount
        };
    }

    // Admin operation: Update car details
    remote function UpdateCar(UpdateCarRequest request) returns UpdateCarResponse|error {
        log:printInfo("Updating car: " + request.plate);
        
        if !carInventory.hasKey(request.plate) {
            return {
                success: false,
                message: "Car with plate " + request.plate + " not found",
                updated_car: request.updated_car
            };
        }
        
        Car updatedCar = request.updated_car;
        updatedCar.plate = request.plate; // Ensure plate doesn't change
        carInventory[request.plate] = updatedCar;
        
        return {
            success: true,
            message: "Car updated successfully",
            updated_car: updatedCar
        };
    }

    // Admin operation: Remove a car
    remote function RemoveCar(RemoveCarRequest request) returns CarListResponse|error {
        log:printInfo("Removing car: " + request.plate);
        
        if !isValidUser(request.admin_id, "ADMIN") {
            return error("Unauthorized: Admin access required");
        }
        
        if !carInventory.hasKey(request.plate) {
            return {
                cars: carInventory.toArray(),
                total_count: carInventory.length()
            };
        }
        
        _ = carInventory.remove(request.plate);
        
        return {
            cars: carInventory.toArray(),
            total_count: carInventory.length()
        };
    }

    // Admin operation: List all reservations (streaming response)
    remote function ListAllReservations(ListReservationsRequest request) returns stream<Reservation, error?>|error {
        log:printInfo("Listing all reservations for admin: " + request.admin_id);
        
        if !isValidUser(request.admin_id, "ADMIN") {
            return error("Unauthorized: Admin access required");
        }
        
        Reservation[] filteredReservations = [];
        
        foreach Reservation reservation in reservations {
            if request.status_filter is ReservationStatus {
                if reservation.status == request.status_filter {
                    filteredReservations.push(reservation);
                }
            } else {
                filteredReservations.push(reservation);
            }
        }
        
        return filteredReservations.toStream();
    }

    // Customer operation: List available cars (streaming response)
    remote function ListAvailableCars(ListCarsRequest request) returns stream<Car, error?>|error {
        log:printInfo("Listing available cars for customer: " + request.customer_id);
        
        if !isValidUser(request.customer_id, "CUSTOMER") {
            return error("Unauthorized: Customer access required");
        }
        
        Car[] availableCars = [];
        
        foreach Car car in carInventory {
            if car.status != "AVAILABLE" {
                continue;
            }
            
            boolean matches = true;
            
            // Apply filters
            if request.search_text is string {
                string searchText = <string>request.search_text;
                searchText = searchText.toLowerAscii();
                if !(car.make.toLowerAscii().includes(searchText) || 
                     car.model.toLowerAscii().includes(searchText)) {
                    matches = false;
                }
            }
            
            if request.year_filter is int && car.year != request.year_filter {
                matches = false;
            }
            
            if request.max_price is float && car.daily_price > request.max_price {
                matches = false;
            }
            
            if request.category_filter is string && car.category != request.category_filter {
                matches = false;
            }
            
            if matches {
                availableCars.push(car);
            }
        }
        
        return availableCars.toStream();
    }

    // Customer operation: Search for a specific car
    remote function SearchCar(SearchCarRequest request) returns SearchCarResponse|error {
        log:printInfo("Searching for car: " + request.plate);
        
        if !isValidUser(request.customer_id, "CUSTOMER") {
            return error("Unauthorized: Customer access required");
        }
        
        if !carInventory.hasKey(request.plate) {
            return {
                found: false,
                available: false,
                car: (),
                message: "Car not found"
            };
        }
        
        Car car = carInventory.get(request.plate);
        boolean available = car.status == "AVAILABLE";
        
        return {
            found: true,
            available: available,
            car: car,
            message: available ? "Car is available" : "Car is not available"
        };
    }

    // Customer operation: Add car to cart
    remote function AddToCart(AddToCartRequest request) returns AddToCartResponse|error {
        log:printInfo("Adding to cart - Customer: " + request.customer_id + ", Car: " + request.plate);
        
        if !isValidUser(request.customer_id, "CUSTOMER") {
            return error("Unauthorized: Customer access required");
        }
        
        // Validate dates and availability
        if !isCarAvailable(request.plate, request.start_date, request.end_date) {
            return {
                success: false,
                message: "Car is not available for the selected dates",
                added_item: (),
                cart_items_count: 0
            };
        }
        
        int days = check calculateDays(request.start_date, request.end_date);
        if days <= 0 {
            return {
                success: false,
                message: "Invalid date range",
                added_item: (),
                cart_items_count: 0
            };
        }
        
        Car car = carInventory.get(request.plate);
        float totalPrice = car.daily_price * days;
        
        CartItem cartItem = {
            plate: request.plate,
            start_date: request.start_date,
            end_date: request.end_date,
            days: days,
            total_price: totalPrice,
            car_details: car
        };
        
        // Add to customer's cart
        CartItem[] currentCart = customerCarts.get(request.customer_id);
        currentCart.push(cartItem);
        customerCarts[request.customer_id] = currentCart;
        
        return {
            success: true,
            message: "Car added to cart successfully",
            added_item: cartItem,
            cart_items_count: currentCart.length()
        };
    }

    // Customer operation: Place reservation
    remote function PlaceReservation(PlaceReservationRequest request) returns PlaceReservationResponse|error {
        log:printInfo("Placing reservation for customer: " + request.customer_id);
        
        if !isValidUser(request.customer_id, "CUSTOMER") {
            return error("Unauthorized: Customer access required");
        }
        
        CartItem[] cart = customerCarts.get(request.customer_id);
        if cart.length() == 0 {
            return {
                success: false,
                message: "Cart is empty",
                reservations: [],
                total_amount: 0.0
            };
        }
        
        // Verify all cars are still available
        foreach CartItem item in cart {
            if !isCarAvailable(item.plate, item.start_date, item.end_date) {
                return {
                    success: false,
                    message: "Car " + item.plate + " is no longer available for selected dates",
                    reservations: [],
                    total_amount: 0.0
                };
            }
        }
        
        // Create reservations
        Reservation[] newReservations = [];
        float totalAmount = 0.0;
        User customer = users.get(request.customer_id);
        string currentTime = time:utcToString(time:utcNow());
        
        foreach CartItem item in cart {
            string reservationId = uuid:createType4AsString();
            
            Reservation reservation = {
                reservation_id: reservationId,
                customer_id: request.customer_id,
                plate: item.plate,
                start_date: item.start_date,
                end_date: item.end_date,
                days: item.days,
                total_price: item.total_price,
                status: "CONFIRMED",
                created_at: currentTime,
                car_details: item.car_details,
                customer_details: customer
            };
            
            reservations[reservationId] = reservation;
            newReservations.push(reservation);
            totalAmount += item.total_price;
        }
        
        // Clear cart
        customerCarts[request.customer_id] = [];
        
        return {
            success: true,
            message: "Reservations placed successfully",
            reservations: newReservations,
            total_amount: totalAmount
        };
    }

    // Common operation: Get cart contents
    remote function GetCart(GetCartRequest request) returns CartResponse|error {
        log:printInfo("Getting cart for customer: " + request.customer_id);
        
        if !customerCarts.hasKey(request.customer_id) {
            return {
                items: [],
                total_amount: 0.0,
                total_items: 0
            };
        }
        
        CartItem[] cart = customerCarts.get(request.customer_id);
        float totalAmount = 0.0;
        
        foreach CartItem item in cart {
            totalAmount += item.total_price;
        }
        
        return {
            items: cart,
            total_amount: totalAmount,
            total_items: cart.length()
        };
    }

    // Common operation: Clear cart
    remote function ClearCart(ClearCartRequest request) returns ClearCartResponse|error {
        log:printInfo("Clearing cart for customer: " + request.customer_id);
        
        customerCarts[request.customer_id] = [];
        
        return {
            success: true,
            message: "Cart cleared successfully"
        };
    }
}

const string CAR_RENTAL_DESC = "0A0F6361725F72656E74616C2E70726F746F120A6361725F72656E74616C22DD020A034361721206706C6174651801120C6D61(trimmed for brevity)";

import SwiftUI

// MARK: - Models

struct Service: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var price: Double
    var duration: String
    var notes: String
    var category: String
    var availability: Bool
    var rating: Double
}

struct Booking: Identifiable, Codable, Equatable {
    var id = UUID()
    var customerName: String
    var service: Service
    var date: Date
    var notes: String
    var contactNumber: String
    var email: String
    var paymentStatus: PaymentStatus
    var specialRequests: String
    
    static func == (lhs: Booking, rhs: Booking) -> Bool {
        return lhs.id == rhs.id
    }
}


enum PaymentStatus: String, CaseIterable, Codable, Identifiable {
    case paid = "Paid"
    case pending = "Pending"
    case overdue = "Overdue"
    
    var id: String { self.rawValue }
}

struct Settings: Codable {
    var isDarkMode: Bool = false
    var serviceSortOption: ServiceSortOption = .name
    var bookingSortOption: BookingSortOption = .date
    var sortOrder: SortOrder = .ascending
}

enum ServiceSortOption: String, CaseIterable, Codable, Identifiable {
    case name = "Name"
    case price = "Price"
    
    var id: String { self.rawValue }
}

enum BookingSortOption: String, CaseIterable, Codable, Identifiable {
    case date = "Date"
    case customerName = "Customer Name"
    
    var id: String { self.rawValue }
}

enum SortOrder: String, CaseIterable, Codable, Identifiable {
    case ascending = "Ascending"
    case descending = "Descending"
    
    var id: String { self.rawValue }
}

// MARK: - Managers

class ServiceManager: ObservableObject {
    @Published var services: [Service] = [] {
        didSet {
            saveServices()
        }
    }
    
    init() {
        loadServices()
    }
    
    func addService(_ service: Service) {
        services.append(service)
    }
    
    func updateService(_ service: Service) {
        if let index = services.firstIndex(where: { $0.id == service.id }) {
            services[index] = service
        }
    }
    
    func deleteServices(at offsets: IndexSet) {
        services.remove(atOffsets: offsets)
    }
    
    private func loadServices() {
        if let data = UserDefaults.standard.data(forKey: "services"),
           let decoded = try? JSONDecoder().decode([Service].self, from: data) {
            services = decoded
        }
    }
    
    private func saveServices() {
        if let encoded = try? JSONEncoder().encode(services) {
            UserDefaults.standard.set(encoded, forKey: "services")
        }
    }
}


class BookingManager: ObservableObject {
    @Published var bookings: [Booking] = [] {
        didSet {
            saveBookings()
        }
    }
    
    init() {
        loadBookings()
    }
    
    func addBooking(_ booking: Booking) {
        bookings.append(booking)
    }
    
    func updateBooking(_ booking: Booking) {
        if let index = bookings.firstIndex(where: { $0.id == booking.id }) {
            bookings[index] = booking
        }
    }
    
    func deleteBookings(at offsets: IndexSet) {
        bookings.remove(atOffsets: offsets)
    }
    
    private func loadBookings() {
        if let data = UserDefaults.standard.data(forKey: "bookings"),
           let decoded = try? JSONDecoder().decode([Booking].self, from: data) {
            bookings = decoded
        }
    }
    
    private func saveBookings() {
        if let encoded = try? JSONEncoder().encode(bookings) {
            UserDefaults.standard.set(encoded, forKey: "bookings")
        }
    }
}

class SettingsManager: ObservableObject {
    @Published var settings: Settings = Settings() {
        didSet {
            saveSettings()
        }
    }
    
    init() {
        loadSettings()
    }
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "settings"),
           let decoded = try? JSONDecoder().decode(Settings.self, from: data) {
            settings = decoded
        }
    }
    
    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: "settings")
        }
    }
    
    func exportData<T: Encodable>(_ data: T, to filename: String) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        if let encodedData = try? encoder.encode(data) {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(filename).json")
            do {
                try encodedData.write(to: url)
                print("Data exported to \(url)")
            } catch {
                print("Failed to write data to file: \(error.localizedDescription)")
            }
        } else {
            print("Failed to encode data.")
        }
    }
    
    func resetData() {
        UserDefaults.standard.removeObject(forKey: "services")
        UserDefaults.standard.removeObject(forKey: "bookings")
        UserDefaults.standard.removeObject(forKey: "settings")
    }
}


// MARK: - Views

struct ContentView: View {
    @StateObject private var serviceManager = ServiceManager()
    @StateObject private var bookingManager = BookingManager()
    @StateObject private var settingsManager = SettingsManager()
    
    var body: some View {
        TabView {
            ServiceListView()
                .tabItem {
                    Label("Services", systemImage: "camera.fill")
                }
                .environmentObject(serviceManager)
                .environmentObject(settingsManager)
            
            BookingListView()
                .tabItem {
                    Label("Bookings", systemImage: "calendar")
                }
                .environmentObject(serviceManager)
                .environmentObject(bookingManager)
                .environmentObject(settingsManager)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .environmentObject(serviceManager)
                .environmentObject(bookingManager)
                .environmentObject(settingsManager)
        }
        .preferredColorScheme(settingsManager.settings.isDarkMode ? .dark : .light)
    }
}


// MARK: Service Views

struct ServiceListView: View {
    @EnvironmentObject var serviceManager: ServiceManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showingAddService = false
    @State private var searchText = ""
    @State private var serviceToDelete: Service?
    @State private var showDeleteConfirmation = false
    
    var sortedServices: [Service] {
        let services = settingsManager.settings.sortOrder == .ascending ? serviceManager.services.sorted {
            settingsManager.settings.serviceSortOption == .name ? $0.name.lowercased() < $1.name.lowercased() : $0.price < $1.price
        } : serviceManager.services.sorted {
            settingsManager.settings.serviceSortOption == .name ? $0.name.lowercased() > $1.name.lowercased() : $0.price > $1.price
        }
        return services
    }
    
    var filteredServices: [Service] {
        if searchText.isEmpty {
            return sortedServices
        } else {
            return sortedServices.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredServices) { service in
                    NavigationLink(destination: EditServiceView(service: service)) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(service.name)
                                    .font(.headline)
                                Text("Duration: \(service.duration)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("Category: \(service.category)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                HStack {
                                    Text("Rating: \(String(format: "%.1f", service.rating))/5")
                                    Text(service.availability ? "Available" : "Unavailable")
                                        .foregroundColor(service.availability ? .green : .red)
                                }
                                .font(.subheadline)
                            }
                            Spacer()
                            Text("$\(service.price, specifier: "%.2f")")
                                .font(.subheadline)
                        }
                        .padding(.vertical, 5)
                    }
                }
                .onDelete { indexSet in
                    if let index = indexSet.first {
                        serviceToDelete = filteredServices[index]
                        showDeleteConfirmation = true
                    }
                }
            }
            .navigationTitle("Services")
            .navigationBarItems(trailing:
                                    Button(action: {
                                        showingAddService = true
                                    }) {
                                        Image(systemName: "plus")
                                    }
            )
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .sheet(isPresented: $showingAddService) {
                AddServiceView()
            }
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text("Confirm Delete"),
                    message: Text("Are you sure you want to delete this service? This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        if let service = serviceToDelete, let index = serviceManager.services.firstIndex(of: service) {
                            serviceManager.services.remove(at: index)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}



struct AddServiceView: View {
    @EnvironmentObject var serviceManager: ServiceManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name = ""
    @State private var price = ""
    @State private var duration = ""
    @State private var notes = ""
    @State private var category = ""
    @State private var availability = true
    @State private var rating = 3.0
    
    let categories = ["Photography", "Videography", "Editing", "Rental"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Service Details")) {
                    TextField("Service Name", text: $name)
                    
                    TextField("Price", text: $price)
                        .keyboardType(.decimalPad)
                    
                    TextField("Duration", text: $duration)
                    
                    TextField("Notes", text: $notes)
                    
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    
                    Toggle("Availability", isOn: $availability)
                    
                    Slider(value: $rating, in: 1...5, step: 0.1) {
                        Text("Rating")
                    }
                    Text("Rating: \(String(format: "%.1f", rating))/5")
                }
            }
            .navigationTitle("Add Service")
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }, trailing: Button("Save") {
                guard let servicePrice = Double(price) else { return }
                let newService = Service(name: name, price: servicePrice, duration: duration, notes: notes, category: category, availability: availability, rating: rating)
                serviceManager.addService(newService)
                presentationMode.wrappedValue.dismiss()
            }.disabled(name.isEmpty || price.isEmpty || duration.isEmpty))
        }
    }
}

struct EditServiceView: View {
    @EnvironmentObject var serviceManager: ServiceManager
    @Environment(\.presentationMode) var presentationMode
    
    @State var service: Service
    
    var body: some View {
        Form {
            Section(header: Text("Service Details")) {
                TextField("Service Name", text: $service.name)
                
                TextField("Price", value: $service.price, formatter: NumberFormatter.currency)
                    .keyboardType(.decimalPad)
                
                TextField("Duration", text: $service.duration)
                
                TextField("Notes", text: $service.notes)
                
                Picker("Category", selection: $service.category) {
                    ForEach(["Photography", "Videography", "Editing", "Rental"], id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                
                Toggle("Availability", isOn: $service.availability)
                
                Slider(value: $service.rating, in: 1...5, step: 0.1) {
                    Text("Rating")
                }
                Text("Rating: \(String(format: "%.1f", service.rating))/5")
            }
        }
        .navigationTitle("Edit Service")
        .navigationBarItems(trailing: Button("Save") {
            serviceManager.updateService(service)
            presentationMode.wrappedValue.dismiss()
        }.disabled(service.name.isEmpty || service.duration.isEmpty))
    }
}

// MARK: Booking Views

struct BookingListView: View {
    @EnvironmentObject var bookingManager: BookingManager
    @EnvironmentObject var serviceManager: ServiceManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showingAddBooking = false
    @State private var searchText = ""
    @State private var bookingToDelete: Booking?
    @State private var showDeleteConfirmation = false
    
    var sortedBookings: [Booking] {
        let bookings = settingsManager.settings.sortOrder == .ascending ? bookingManager.bookings.sorted {
            settingsManager.settings.bookingSortOption == .date ? $0.date < $1.date : $0.customerName.lowercased() < $1.customerName.lowercased()
        } : bookingManager.bookings.sorted {
            settingsManager.settings.bookingSortOption == .date ? $0.date > $1.date : $0.customerName.lowercased() > $1.customerName.lowercased()
        }
        return bookings
    }
    
    var filteredBookings: [Booking] {
        if searchText.isEmpty {
            return sortedBookings
        } else {
            return sortedBookings.filter { $0.customerName.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredBookings) { booking in
                    NavigationLink(destination: EditBookingView(booking: booking)) {
                        VStack(alignment: .leading) {
                            Text(booking.customerName)
                                .font(.headline)
                            Text(booking.service.name)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(booking.date.formatted(date: .long, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Payment: \(booking.paymentStatus.rawValue)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Contact: \(booking.contactNumber)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 5)
                    }
                }
                .onDelete { indexSet in
                    if let index = indexSet.first {
                        bookingToDelete = filteredBookings[index]
                        showDeleteConfirmation = true
                    }
                }
            }
            .navigationTitle("Bookings")
            .navigationBarItems(trailing:
                                    Button(action: {
                                        showingAddBooking = true
                                    }) {
                                        Image(systemName: "plus")
                                    }
                                    .disabled(serviceManager.services.isEmpty)
            )
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .sheet(isPresented: $showingAddBooking) {
                AddBookingView()
            }
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text("Confirm Delete"),
                    message: Text("Are you sure you want to delete this booking? This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        if let booking = bookingToDelete, let index = bookingManager.bookings.firstIndex(of: booking) {
                            bookingManager.bookings.remove(at: index)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}


struct AddBookingView: View {
    @EnvironmentObject var bookingManager: BookingManager
    @EnvironmentObject var serviceManager: ServiceManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var customerName = ""
    @State private var selectedService: Service?
    @State private var date = Date()
    @State private var notes = ""
    @State private var contactNumber = ""
    @State private var email = ""
    @State private var paymentStatus: PaymentStatus = .pending
    @State private var specialRequests = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Customer Details")) {
                    TextField("Customer Name", text: $customerName)
                    TextField("Contact Number", text: $contactNumber)
                        .keyboardType(.phonePad)
                    TextField("Email Address", text: $email)
                        .keyboardType(.emailAddress)
                }
                
                Section(header: Text("Service Details")) {
                    Picker("Service", selection: $selectedService) {
                        ForEach(serviceManager.services, id: \.self) { service in
                            Text(service.name).tag(Optional(service))
                        }
                    }
                }
                
                Section(header: Text("Booking Details")) {
                    DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    
                    Picker("Payment Status", selection: $paymentStatus) {
                        ForEach(PaymentStatus.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    
                    TextField("Special Requests", text: $specialRequests)
                    TextField("Notes", text: $notes)
                }
            }
            .navigationTitle("Add Booking")
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }, trailing: Button("Save") {
                if let service = selectedService {
                    let newBooking = Booking(customerName: customerName, service: service, date: date, notes: notes, contactNumber: contactNumber, email: email, paymentStatus: paymentStatus, specialRequests: specialRequests)
                    bookingManager.addBooking(newBooking)
                    presentationMode.wrappedValue.dismiss()
                }
            }.disabled(customerName.isEmpty || selectedService == nil))
        }
    }
}

struct EditBookingView: View {
    @EnvironmentObject var bookingManager: BookingManager
    @EnvironmentObject var serviceManager: ServiceManager
    @Environment(\.presentationMode) var presentationMode
    
    @State var booking: Booking
    
    var body: some View {
        Form {
            Section(header: Text("Customer Details")) {
                TextField("Customer Name", text: $booking.customerName)
                TextField("Contact Number", text: $booking.contactNumber)
                    .keyboardType(.phonePad)
                TextField("Email Address", text: $booking.email)
                    .keyboardType(.emailAddress)
            }
            
            Section(header: Text("Service Details")) {
                Picker("Service", selection: $booking.service) {
                    ForEach(serviceManager.services, id: \.self) { service in
                        Text(service.name).tag(service)
                    }
                }
            }
            
            Section(header: Text("Booking Details")) {
                DatePicker("Date & Time", selection: $booking.date, displayedComponents: [.date, .hourAndMinute])
                
                Picker("Payment Status", selection: $booking.paymentStatus) {
                    ForEach(PaymentStatus.allCases) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                
                TextField("Special Requests", text: $booking.specialRequests)
                TextField("Notes", text: $booking.notes)
            }
        }
        .navigationTitle("Edit Booking")
        .navigationBarItems(trailing: Button("Save") {
            bookingManager.updateBooking(booking)
            presentationMode.wrappedValue.dismiss()
        }.disabled(booking.customerName.isEmpty))
    }
}

// MARK: Settings View

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var serviceManager: ServiceManager
    @EnvironmentObject var bookingManager: BookingManager
    
    @State private var showResetConfirmation = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Appearance")) {
                    Toggle(isOn: $settingsManager.settings.isDarkMode) {
                        Text("Dark Mode")
                    }
                }
                
                Section(header: Text("Sorting Options")) {
                    Picker("Service Sort By", selection: $settingsManager.settings.serviceSortOption) {
                        ForEach(ServiceSortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    
                    Picker("Booking Sort By", selection: $settingsManager.settings.bookingSortOption) {
                        ForEach(BookingSortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    
                    Picker("Sort Order", selection: $settingsManager.settings.sortOrder) {
                        ForEach(SortOrder.allCases) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                }
                
                Section(header: Text("Data Management")) {
                    Button("Reset Data") {
                        showResetConfirmation = true
                    }
                    .alert(isPresented: $showResetConfirmation) {
                        Alert(
                            title: Text("Confirm Reset"),
                            message: Text("Are you sure you want to reset all data? This action cannot be undone."),
                            primaryButton: .destructive(Text("Reset")) {
                                settingsManager.resetData()
                                serviceManager.services.removeAll()
                                bookingManager.bookings.removeAll()
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}





// MARK: - Number Formatter Extension

extension NumberFormatter {
    static var currency: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        if #available(iOS 16, *) {
            formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        } else {
            // Fallback on earlier versions
        }
        return formatter
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

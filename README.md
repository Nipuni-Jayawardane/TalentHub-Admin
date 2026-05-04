# SLT TalentHub Admin Portal

A Flutter-based admin portal for managing the SLT TalentHub internship attendance system.

## Features

### 📊 Dashboard Analytics
- Real-time statistics and metrics
- Visual charts and graphs using FL Chart
- Intern performance overview
- Daily attendance summaries

### 👥 Intern Management
- Complete intern profiles and details
- Search and filter functionality
- Individual intern records view
- Attendance history tracking

### 📋 Daily Records Management
- View all daily attendance records
- Paginated data with search capabilities
- Export functionality for data analysis
- Date-based filtering

### 📤 Export Capabilities
- **Export Non Submissions**: NEW! Export interns who haven't submitted attendance for a selected date range
- **Export Daily Records**: Download complete attendance records as CSV
- **Export On-Leave Data**: Export leave records in Excel format
- Date range selection with intuitive date picker

### 🔔 Notification System
- Send notifications to overdue interns
- Bulk notification capabilities
- Real-time feedback and status updates

### 🔐 Authentication & Security
- Secure admin login with JWT tokens
- Google Sign-In integration
- Token-based API authentication
- Secure storage of credentials

## Technical Stack

### Frontend
- **Flutter 3.35.7** with Dart 3.9.2
- **Material Design 3** UI components
- **Go Router** for navigation
- **Provider** for state management

### Key Dependencies
- `http: ^1.4.0` - API communication
- `go_router: ^12.1.3` - Navigation
- `shared_preferences: ^2.2.0` - Local storage
- `csv: ^6.0.0` - CSV file generation
- `fl_chart: ^1.0.0` - Charts and graphs
- `google_fonts: ^6.3.0` - Typography
- `intl: ^0.20.2` - Internationalization

### Platform Support
- ✅ iOS (iPhone/iPad)
- ✅ macOS Desktop
- ✅ Android
- ⚠️ Web (limited due to CORS restrictions)

## API Integration

### Backend Endpoints
- **Base URL**: `https://talenthub.slt.lk/api`
- **Authentication**: JWT Bearer tokens
- **Data Format**: JSON

### Key API Endpoints Used
- `POST /auth/login` - Admin authentication
- `GET /admin/dashboard/stats` - Dashboard statistics
- `GET /admin/report/interns` - Intern reports
- `GET /admin/daily-records` - Daily attendance records
- `GET /admin/previous-day-submissions` - Previous day data
- `POST /admin/notifications/overdue` - Send notifications
- `GET /admin/intern/:id` - Individual intern details
- `GET /admin/search/interns` - Search functionality

## Installation & Setup

### Prerequisites
- Flutter SDK 3.35.7 or higher
- Dart SDK 3.9.2 or higher
- iOS development: Xcode 16.4+
- macOS development: macOS 15.6.1+

### Installation Steps

1. **Clone the Repository**
   ```bash
   git clone https://github.com/SLT-TalentHub-Mobile-APP/TalentHub-Admin.git
   cd TalentHub-Admin
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Platform Setup**
   ```bash
   # For iOS development
   cd ios && pod install && cd ..
   
   # For macOS development
   flutter create . --platforms=macos
   ```

4. **Run the Application**
   ```bash
   # iOS Simulator
   flutter run -d ios
   
   # macOS Desktop
   flutter run -d macos
   
   # Android
   flutter run -d android
   ```

## Configuration

### Environment Setup
The app uses environment configuration in `lib/config/config.dart`:

```dart
class Config {
  static const String backendBaseUrl = 'https://talenthub.slt.lk/api';
  // Add other configuration variables as needed
}
```

### Build Configuration
- **iOS**: Minimum deployment target iOS 12.0
- **macOS**: Minimum deployment target macOS 10.14
- **Android**: Minimum SDK version 21

## Key Features Implementation

### Export Non Submissions (Latest Feature)
This feature allows admins to export a list of interns who haven't submitted their attendance for a specified date range:

- **Smart Data Processing**: Uses existing API endpoints to calculate non-submissions
- **Date Range Selection**: Intuitive date picker for flexible reporting
- **CSV Export**: Downloads formatted CSV files with intern details
- **Real-time Processing**: Efficient client-side data analysis

### Dashboard Analytics
- Real-time metrics display
- Interactive charts using FL Chart
- Performance indicators
- Summary statistics

### Advanced Search & Filtering
- Multi-parameter search functionality
- Date-based filtering
- Pagination for large datasets
- Export capabilities for filtered data

## Development Notes

### Architecture
- **Feature-based structure** with separate modules for admin functionality
- **Clean API layer** with comprehensive error handling
- **Responsive UI** that works across all supported platforms
- **State management** using Provider pattern

### Performance Optimizations
- **Caching Strategy**: Daily records cached for 1 hour
- **Lazy Loading**: Paginated data loading for large datasets
- **Memory Management**: Efficient data processing for large CSV exports
- **Background Processing**: Non-blocking UI during data operations

### Error Handling
- Comprehensive API error handling
- User-friendly error messages
- Offline capability considerations
- Graceful fallbacks for network issues

## Troubleshooting

### Common Issues

1. **CORS Issues on Web**
   - **Solution**: Use iOS/macOS/Android instead of web platform
   - Web support is limited due to browser security restrictions

2. **Build Issues**
   - Clean build: `flutter clean && flutter pub get`
   - Update dependencies: `flutter pub upgrade`

3. **iOS/macOS Build Issues**
   - Update CocoaPods: `pod repo update`
   - Clear Xcode cache: `rm -rf ~/Library/Developer/Xcode/DerivedData`

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-feature`
3. Commit changes: `git commit -am 'Add new feature'`
4. Push to branch: `git push origin feature/new-feature`
5. Submit a Pull Request

## License

This project is part of the SLT TalentHub ecosystem and follows the organization's licensing terms.

## Support

For technical support or questions:
- Create an issue in this repository
- Contact the SLT TalentHub development team

---

**Built with ❤️ using Flutter for SLT TalentHub**

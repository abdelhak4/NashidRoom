# NashidRoom - Social nashid Listening App

NashidRoom is a social nashid streaming application that allows users to create and join listening events, share tracks, vote on playlists, and enjoy nashid together in real-time. Whether hosting a remote listening party or discovering new nashid with friends, NashidRoom makes collaborative listening seamless and interactive.

## Demo

- **Click to whach 👇**
<a href="https://vimeo.com/1111701620">
  <img src="https://github.com/user-attachments/assets/691cc4a1-8583-4bc7-86b0-01c6bd04be73" width="600" height="2000" />
</a>



## Features

- **Event Creation**: Host public or private nashid listening events
- **YouTube Integration**: Search and share nashid directly from YouTube
- **Social Features**: Friend system with invitations
- **Real-time Voting**: Collaborative playlist voting system
- **Location-based Events**: Create geo-restricted events for local gatherings
- **Premium Features**: Different license tiers for hosts and listeners
- **User Profiles**: Customizable user profiles with bio, image, and preferences
- **Authentication**: Multiple sign-in methods (email, Google)

## Technology Stack

- **Frontend**: Swift / SwiftUI
- **Backend**: Supabase (PostgreSQL + RESTful API)
- **Authentication**: Supabase Auth + Google Sign-In
- **Media Integration**: YouTube Data API
- **Real-time Updates**: Supabase Realtime (with polling fallback)
- **Geolocation**: CoreLocation for location-based events
- **State Management**: SwiftUI ObservableObject pattern

## Setup & Installation

### Prerequisites

- Xcode 14+ 
- iOS 15.0+ target device
- Supabase account
- Google Cloud project with YouTube Data API enabled
- Google OAuth client ID for sign-in

### Setting Up Supabase

1. Create a new Supabase project at [supabase.com](https://supabase.com)
2. Run the complete SQL setup script in your Supabase SQL Editor:

```bash
# Copy the entire content of COMPLETE_SUPABASE_SETUP.sql to the SQL Editor in Supabase
# Click "Run" to execute the SQL script
```

The script will:
- Create all required tables with proper schema
- Set up indexes for performance
- Configure Row Level Security (RLS) policies
- Create database functions and triggers for voting mechanics
- Set up helper functions for friend requests, event access, etc.

### Project Configuration

1. Clone the repository:
```bash
git clone git@github.com:abdelhak4/NashidRoom.git
cd NashidRoom
```

2. Open the project in Xcode:
```bash
open PodcastRoom.xcodeproj
```

3. Configure your Info.plist with the required API keys:
   - `SUPABASE_URL`: Your Supabase project URL
   - `SUPABASE_ANON_KEY`: Your Supabase anonymous key
   - `YOUTUBE_API_KEY`: Your YouTube Data API key
   - `GIDClientID`: Your Google OAuth client ID

4. Add the required URL schemes to your Info.plist for authentication callbacks

5. Build and run the app on your device or simulator

## Project Structure

```
PodcastRoom/
├── App/ - Application entry point and lifecycle management
├── Assets/ - Images, colors, and resources
├── Config/ - Configuration constants and environment settings
├── Core/
│   ├── Managers/ - Global managers for app-wide functionality
│   ├── Models/ - Data models and structures
│   └── Services/ - API and backend integration services
├── Features/
│   ├── Authentication/ - Login, registration, and account management
│   ├── Events/ - Event creation and participation
│   ├── Explore/ - Discover public events
│   ├── Library/ - User's collection and history
│   ├── Main/ - Main app navigation and structure
│   ├── nashidPlaylistEditor/ - Playlist management
│   ├── NowPlaying/ - Active listening experience
│   └── Profile/ - User profile management
└── UI/
    ├── Components/ - Reusable UI components
    └── Extensions/ - SwiftUI extensions and utilities
```

## API Integration

### Supabase Integration

The app connects to Supabase for:
- User authentication and profile management
- Event creation and management
- Track voting and playlist management
- Friend relationships and invitations
- Real-time data synchronization

### YouTube API Integration

YouTube integration allows users to:
- Search for nashid videos
- Add YouTube content to event playlists
- Stream YouTube content directly in the app
- View track metadata and thumbnails

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Contact

Project Owner - [@abdelhak4](https://github.com/abdelhak4)

Project Repository: [https://github.com/abdelhak4/NashidRoom](https://github.com/abdelhak4/NashidRoom)

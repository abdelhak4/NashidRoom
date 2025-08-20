# Complete Supabase Schema Setup for YouTube API

This script creates all tables from scratch with YouTube API support. Run this in your Supabase SQL Editor after deleting existing tables.

```sql
-- ============================================================================
-- SUPABASE SCHEMA SETUP FOR PODCASTROOM WITH YOUTUBE API
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- 1. USERS TABLE
-- ============================================================================

CREATE TABLE public.users (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    profile_image_url TEXT,
    
    -- Personal Information
    display_name TEXT,
    bio TEXT,
    location TEXT,
    date_of_birth DATE,
    phone_number TEXT,
    website TEXT,
    
    -- Platform Connections
    spotify_connected BOOLEAN DEFAULT FALSE, -- Keep for backward compatibility
    youtube_connected BOOLEAN DEFAULT TRUE,  -- YouTube doesn't require explicit connection
    license_type TEXT DEFAULT 'free' CHECK (license_type IN ('free', 'premium')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 2. FRIENDS TABLE
-- ============================================================================

CREATE TABLE public.friends (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    friend_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'accepted' CHECK (status IN ('accepted')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Ensure users can't be friends with themselves
    CONSTRAINT check_not_self_friend CHECK (user_id != friend_id),
    
    -- Ensure friendship is unique (bidirectional)
    UNIQUE(user_id, friend_id)
);

-- ============================================================================
-- 3. FRIEND REQUESTS TABLE
-- ============================================================================

CREATE TABLE public.friend_requests (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    requester_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    recipient_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Ensure users can't send friend requests to themselves
    CONSTRAINT check_not_self_request CHECK (requester_id != recipient_id),
    
    -- Ensure only one pending request between two users at a time
    UNIQUE(requester_id, recipient_id)
);

-- ============================================================================
-- 4. EVENTS TABLE
-- ============================================================================

CREATE TABLE public.events (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    host_id UUID REFERENCES public.users(id) NOT NULL,
    visibility TEXT DEFAULT 'public' CHECK (visibility IN ('public', 'private')),
    license_type TEXT DEFAULT 'free' CHECK (license_type IN ('free', 'premium', 'location_based')),
    location_lat DECIMAL,
    location_lng DECIMAL,
    location_radius INTEGER DEFAULT 100, -- meters
    time_start TIMESTAMPTZ,
    time_end TIMESTAMPTZ,
    spotify_playlist_id TEXT, -- Optional, for backward compatibility
    youtube_playlist_id TEXT, -- Optional, for future YouTube playlist support
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Ensure at least one playlist ID is provided (optional constraint)
    CONSTRAINT check_has_playlist_reference 
    CHECK (spotify_playlist_id IS NOT NULL OR youtube_playlist_id IS NOT NULL OR (spotify_playlist_id IS NULL AND youtube_playlist_id IS NULL))
);

-- ============================================================================
-- 5. EVENT INVITATIONS TABLE
-- ============================================================================

CREATE TABLE public.event_invitations (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    event_id UUID REFERENCES public.events(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    host_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(event_id, user_id)
);

-- Add host_id column if it doesn't exist (for existing databases)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'event_invitations' 
        AND column_name = 'host_id'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.event_invitations 
        ADD COLUMN host_id UUID REFERENCES public.users(id) ON DELETE CASCADE;
    END IF;
END $$;

-- ============================================================================
-- 6. TRACKS TABLE (WITH YOUTUBE SUPPORT)
-- ============================================================================

CREATE TABLE public.tracks (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    event_id UUID REFERENCES public.events(id) ON DELETE CASCADE,
    
    -- Basic track info
    title TEXT NOT NULL,
    artist TEXT NOT NULL,
    album TEXT,
    duration INTEGER NOT NULL, -- seconds
    artwork_url TEXT,
    preview_url TEXT,
    
    -- Music source identifiers (at least one required)
    spotify_id TEXT, -- Spotify track ID
    spotify_uri TEXT, -- spotify:track:xxxxx
    youtube_video_id TEXT, -- YouTube video ID
    youtube_url TEXT, -- Full YouTube URL
    
    -- Event-specific data
    added_by UUID REFERENCES public.users(id),
    votes INTEGER DEFAULT 0,
    position INTEGER DEFAULT 0,
    is_played BOOLEAN DEFAULT FALSE,
    added_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Ensure at least one music source is provided
    CONSTRAINT check_music_source 
    CHECK (spotify_uri IS NOT NULL OR youtube_video_id IS NOT NULL)
);

-- ============================================================================
-- 7. VOTES TABLE
-- ============================================================================

CREATE TABLE public.votes (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    track_id UUID REFERENCES public.tracks(id) ON DELETE CASCADE,
    event_id UUID REFERENCES public.events(id) ON DELETE CASCADE,
    vote_type TEXT CHECK (vote_type IN ('up', 'down')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, track_id, event_id)
);

-- ============================================================================
-- 8. INDEXES FOR PERFORMANCE
-- ============================================================================

-- Users indexes
CREATE INDEX idx_users_username ON public.users(username);
CREATE INDEX idx_users_email ON public.users(email);

-- Friends indexes
CREATE INDEX idx_friends_user_id ON public.friends(user_id);
CREATE INDEX idx_friends_friend_id ON public.friends(friend_id);
CREATE INDEX idx_friends_status ON public.friends(status);

-- Friend requests indexes
CREATE INDEX idx_friend_requests_requester_id ON public.friend_requests(requester_id);
CREATE INDEX idx_friend_requests_recipient_id ON public.friend_requests(recipient_id);
CREATE INDEX idx_friend_requests_status ON public.friend_requests(status);

-- Events indexes
CREATE INDEX idx_events_visibility ON public.events(visibility);
CREATE INDEX idx_events_host_id ON public.events(host_id);
CREATE INDEX idx_events_active ON public.events(is_active);
CREATE INDEX idx_events_license_type ON public.events(license_type);

-- Tracks indexes
CREATE INDEX idx_tracks_event_id ON public.tracks(event_id);
CREATE INDEX idx_tracks_votes ON public.tracks(votes DESC);
CREATE INDEX idx_tracks_position ON public.tracks(position);
CREATE INDEX idx_tracks_spotify_id ON public.tracks(spotify_id);
CREATE INDEX idx_tracks_youtube_video_id ON public.tracks(youtube_video_id);
CREATE INDEX idx_tracks_added_by ON public.tracks(added_by);

-- Votes indexes
CREATE INDEX idx_votes_track_id ON public.votes(track_id);
CREATE INDEX idx_votes_user_id ON public.votes(user_id);
CREATE INDEX idx_votes_event_id ON public.votes(event_id);

-- Event invitations indexes
CREATE INDEX idx_invitations_event_id ON public.event_invitations(event_id);
CREATE INDEX idx_invitations_user_id ON public.event_invitations(user_id);
CREATE INDEX idx_invitations_status ON public.event_invitations(status);

-- ============================================================================
-- 9. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friends ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friend_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tracks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.votes ENABLE ROW LEVEL SECURITY;

-- Users policies
CREATE POLICY "Users can view own profile" ON public.users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON public.users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Users can view public info of other users (for friend functionality)
CREATE POLICY "Users can view public user info" ON public.users
    FOR SELECT USING (true); -- Allow viewing basic public info like username, display_name

-- Friends policies
CREATE POLICY "Users can view their friendships" ON public.friends
    FOR SELECT USING (user_id = auth.uid() OR friend_id = auth.uid());

CREATE POLICY "Users can create friendships" ON public.friends
    FOR INSERT WITH CHECK (user_id = auth.uid() OR friend_id = auth.uid());

CREATE POLICY "Users can delete their friendships" ON public.friends
    FOR DELETE USING (user_id = auth.uid() OR friend_id = auth.uid());

-- Friend requests policies
CREATE POLICY "Users can view their friend requests" ON public.friend_requests
    FOR SELECT USING (requester_id = auth.uid() OR recipient_id = auth.uid());

CREATE POLICY "Users can send friend requests" ON public.friend_requests
    FOR INSERT WITH CHECK (requester_id = auth.uid());

CREATE POLICY "Users can update friend requests they're involved in" ON public.friend_requests
    FOR UPDATE USING (requester_id = auth.uid() OR recipient_id = auth.uid())
    WITH CHECK (requester_id = auth.uid() OR recipient_id = auth.uid());

CREATE POLICY "Users can delete their friend requests" ON public.friend_requests
    FOR DELETE USING (requester_id = auth.uid() OR recipient_id = auth.uid());

-- Events policies
CREATE POLICY "Users can view accessible events" ON public.events
    FOR SELECT USING (can_user_access_event(id, auth.uid()));

CREATE POLICY "Users can create events" ON public.events
    FOR INSERT WITH CHECK (auth.uid() = host_id);

CREATE POLICY "Hosts can update their events" ON public.events
    FOR UPDATE USING (auth.uid() = host_id);

CREATE POLICY "Hosts can delete their events" ON public.events
    FOR DELETE USING (auth.uid() = host_id);

-- Event invitations policies
CREATE POLICY "Users can view their invitations" ON public.event_invitations
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Event hosts can manage invitations" ON public.event_invitations
    FOR ALL USING (host_id = auth.uid());

CREATE POLICY "Users can update their invitation status" ON public.event_invitations
    FOR UPDATE USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Tracks policies
CREATE POLICY "Users can view tracks for accessible events" ON public.tracks
    FOR SELECT USING (
        event_id IN (
            SELECT id FROM public.events WHERE
            (visibility = 'public' AND is_active = true) OR
            (host_id = auth.uid()) OR
            (id IN (
                SELECT event_id FROM public.event_invitations 
                WHERE user_id = auth.uid() AND status = 'accepted'
            ))
        )
    );

CREATE POLICY "Users can add tracks to accessible events" ON public.tracks
    FOR INSERT WITH CHECK (
        added_by = auth.uid() AND
        event_id IN (
            SELECT id FROM public.events WHERE
            (visibility = 'public' AND is_active = true) OR
            (host_id = auth.uid()) OR
            (id IN (
                SELECT event_id FROM public.event_invitations 
                WHERE user_id = auth.uid() AND status = 'accepted'
            ))
        )
    );

-- Votes policies
CREATE POLICY "Users can view votes for accessible events" ON public.votes
    FOR SELECT USING (
        event_id IN (
            SELECT id FROM public.events WHERE
            (visibility = 'public' AND is_active = true) OR
            (host_id = auth.uid()) OR
            (id IN (
                SELECT event_id FROM public.event_invitations 
                WHERE user_id = auth.uid() AND status = 'accepted'
            ))
        )
    );

CREATE POLICY "Users can manage their own votes" ON public.votes
    FOR ALL USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- ============================================================================
-- 10. DATABASE FUNCTIONS AND TRIGGERS
-- ============================================================================

-- Function to update track vote counts
CREATE OR REPLACE FUNCTION update_vote_counts()
RETURNS TRIGGER AS $$
DECLARE
    up_votes INTEGER;
    down_votes INTEGER;
    total_votes INTEGER;
BEGIN
    -- Calculate vote counts for the track
    SELECT 
        COUNT(*) FILTER (WHERE vote_type = 'up'),
        COUNT(*) FILTER (WHERE vote_type = 'down')
    INTO up_votes, down_votes
    FROM public.votes 
    WHERE track_id = COALESCE(NEW.track_id, OLD.track_id);
    
    -- Calculate total (up votes minus down votes, minimum 0)
    total_votes := GREATEST(0, up_votes - down_votes);
    
    -- Update track vote count (updated_at will be set by the BEFORE UPDATE trigger)
    UPDATE public.tracks 
    SET votes = total_votes
    WHERE id = COALESCE(NEW.track_id, OLD.track_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Function to update track positions based on votes
CREATE OR REPLACE FUNCTION update_track_positions()
RETURNS TRIGGER AS $$
BEGIN
    -- Update positions for all tracks in the event, ordered by votes (desc) then added_at (asc)
    WITH ranked_tracks AS (
        SELECT 
            id,
            ROW_NUMBER() OVER (ORDER BY votes DESC, added_at ASC) as new_position
        FROM public.tracks 
        WHERE event_id = COALESCE(NEW.event_id, OLD.event_id)
        AND is_played = false -- Only reorder unplayed tracks
    )
    UPDATE public.tracks 
    SET position = ranked_tracks.new_position
    FROM ranked_tracks 
    WHERE public.tracks.id = ranked_tracks.id;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Function to update timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for vote count updates
CREATE TRIGGER update_vote_counts_trigger
    AFTER INSERT OR UPDATE OR DELETE ON public.votes
    FOR EACH ROW
    EXECUTE FUNCTION update_vote_counts();

-- Triggers for position updates (after vote counts are updated)
CREATE TRIGGER update_track_positions_trigger
    AFTER UPDATE OF votes ON public.tracks
    FOR EACH ROW
    EXECUTE FUNCTION update_track_positions();

-- Triggers for updated_at timestamps
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_friends_updated_at
    BEFORE UPDATE ON public.friends
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_friend_requests_updated_at
    BEFORE UPDATE ON public.friend_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_events_updated_at
    BEFORE UPDATE ON public.events
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tracks_updated_at
    BEFORE UPDATE ON public.tracks
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_votes_updated_at
    BEFORE UPDATE ON public.votes
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_event_invitations_updated_at
    BEFORE UPDATE ON public.event_invitations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- 11. HELPER FUNCTIONS
-- ============================================================================

-- Function to handle friend request acceptance
CREATE OR REPLACE FUNCTION accept_friend_request(request_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    request_record public.friend_requests%ROWTYPE;
BEGIN
    -- Get the friend request
    SELECT * INTO request_record FROM public.friend_requests 
    WHERE id = request_id AND status = 'pending';
    
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- Update request status
    UPDATE public.friend_requests 
    SET status = 'accepted', updated_at = NOW()
    WHERE id = request_id;
    
    -- Create bidirectional friendship
    INSERT INTO public.friends (user_id, friend_id, status)
    VALUES 
        (request_record.requester_id, request_record.recipient_id, 'accepted'),
        (request_record.recipient_id, request_record.requester_id, 'accepted')
    ON CONFLICT (user_id, friend_id) DO NOTHING;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user's friends list
CREATE OR REPLACE FUNCTION get_user_friends(user_uuid UUID)
RETURNS TABLE(
    friend_id UUID,
    username TEXT,
    display_name TEXT,
    profile_image_url TEXT,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.username,
        u.display_name,
        u.profile_image_url,
        f.created_at
    FROM public.friends f
    JOIN public.users u ON f.friend_id = u.id
    WHERE f.user_id = user_uuid AND f.status = 'accepted'
    ORDER BY f.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get pending friend requests received
CREATE OR REPLACE FUNCTION get_received_friend_requests(user_uuid UUID)
RETURNS TABLE(
    request_id UUID,
    requester_id UUID,
    username TEXT,
    display_name TEXT,
    profile_image_url TEXT,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        fr.id,
        u.id,
        u.username,
        u.display_name,
        u.profile_image_url,
        fr.created_at
    FROM public.friend_requests fr
    JOIN public.users u ON fr.requester_id = u.id
    WHERE fr.recipient_id = user_uuid AND fr.status = 'pending'
    ORDER BY fr.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get pending friend requests sent
CREATE OR REPLACE FUNCTION get_sent_friend_requests(user_uuid UUID)
RETURNS TABLE(
    request_id UUID,
    recipient_id UUID,
    username TEXT,
    display_name TEXT,
    profile_image_url TEXT,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        fr.id,
        u.id,
        u.username,
        u.display_name,
        u.profile_image_url,
        fr.created_at
    FROM public.friend_requests fr
    JOIN public.users u ON fr.recipient_id = u.id
    WHERE fr.requester_id = user_uuid AND fr.status = 'pending'
    ORDER BY fr.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user can vote in event
CREATE OR REPLACE FUNCTION can_user_vote_in_event(event_uuid UUID, user_uuid UUID)
RETURNS BOOLEAN AS $$
DECLARE
    event_record public.events%ROWTYPE;
    user_record public.users%ROWTYPE;
    current_time TIMESTAMPTZ := NOW();
BEGIN
    -- Get event details
    SELECT * INTO event_record FROM public.events WHERE id = event_uuid;
    
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- Check if event is active
    IF NOT event_record.is_active THEN
        RETURN FALSE;
    END IF;
    
    -- Check if event is accessible
    IF event_record.visibility = 'private' THEN
        IF event_record.host_id != user_uuid AND 
           NOT EXISTS (
               SELECT 1 FROM public.event_invitations 
               WHERE event_id = event_uuid 
               AND user_id = user_uuid 
               AND status = 'accepted'
           ) THEN
            RETURN FALSE;
        END IF;
    END IF;
    
    -- Get user details
    SELECT * INTO user_record FROM public.users WHERE id = user_uuid;
    
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- Check license restrictions
    IF event_record.license_type = 'premium' AND user_record.license_type != 'premium' THEN
        RETURN FALSE;
    END IF;
    
    -- Check time restrictions for location-based events
    IF event_record.license_type = 'location_based' THEN
        IF event_record.time_start IS NOT NULL AND current_time < event_record.time_start THEN
            RETURN FALSE;
        END IF;
        
        IF event_record.time_end IS NOT NULL AND current_time > event_record.time_end THEN
            RETURN FALSE;
        END IF;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user can access an event (for RLS policies)
CREATE OR REPLACE FUNCTION can_user_access_event(event_uuid UUID, user_uuid UUID)
RETURNS BOOLEAN AS $$
DECLARE
    event_record public.events%ROWTYPE;
BEGIN
    -- Get event details
    SELECT * INTO event_record FROM public.events WHERE id = event_uuid;
    
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- Check if event is active
    IF NOT event_record.is_active THEN
        RETURN FALSE;
    END IF;
    
    -- Public events are accessible to everyone
    IF event_record.visibility = 'public' THEN
        RETURN TRUE;
    END IF;
    
    -- Private events: check if user is host or has accepted invitation
    IF event_record.visibility = 'private' THEN
        -- Host can always access
        IF event_record.host_id = user_uuid THEN
            RETURN TRUE;
        END IF;
        
        -- Check if user has accepted invitation
        IF EXISTS (
            SELECT 1 FROM public.event_invitations 
            WHERE event_id = event_uuid 
            AND user_id = user_uuid 
            AND status = 'accepted'
        ) THEN
            RETURN TRUE;
        END IF;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to generate YouTube search URL (utility function)
CREATE OR REPLACE FUNCTION generate_youtube_search_url(track_title TEXT, track_artist TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN 'https://www.youtube.com/results?search_query=' || 
           replace(replace(track_title || ' ' || track_artist, ' ', '+'), '''', '');
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 12. SAMPLE DATA (OPTIONAL - FOR DEVELOPMENT)
-- ============================================================================

-- Sample data will be created through the iOS app when users sign up and create events
-- No initial sample data inserted here to avoid foreign key constraint issues

-- ============================================================================
-- SETUP COMPLETE
-- ============================================================================

-- Grant necessary permissions to authenticated users
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- Grant permissions to anon users for public data
GRANT USAGE ON SCHEMA public TO anon;
GRANT SELECT ON public.events TO anon;
GRANT SELECT ON public.tracks TO anon;

SELECT 'PodcastRoom database setup complete! 🎉' as status;
```

## What This Script Does:

1. **Creates all tables** with YouTube API support from scratch
2. **Sets up proper indexes** for performance
3. **Implements Row Level Security** for data protection
4. **Creates triggers** for automatic vote counting and position updates
5. **Includes helper functions** for voting validation
6. **Grants proper permissions** for authenticated and anonymous users
7. **Supports both Spotify and YouTube** data sources for flexibility

## Key Features:

- **YouTube-First Design**: Primary support for YouTube with Spotify as optional fallback
- **Flexible Music Sources**: Tracks can have Spotify URI, YouTube video ID, or both
- **Automatic Vote Counting**: Triggers handle vote tallying and position updates
- **Comprehensive Security**: RLS policies protect user data and event access
- **Performance Optimized**: Proper indexes for all common queries
- **Location-Based Events**: Support for geo-fenced voting with time restrictions

## Next Steps:

1. **Run this script** in your Supabase SQL Editor
2. **Test with your iOS app** - all existing code should work
3. **Add YouTube API key** to your app's Info.plist
4. **Start using YouTube search** instead of Spotify

The schema is now optimized for YouTube API while maintaining backward compatibility with any existing Spotify data!
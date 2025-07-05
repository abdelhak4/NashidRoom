import SwiftUI
import WebKit
import Combine

struct YouTubePlayerView: View {
    let videoId: String
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @State private var webView: WKWebView?
    @State private var isReady = false
    @State private var currentVideoId: String
    @State private var lastCommandSent: String = ""  // Track last command sent to prevent loops
    @State private var commandTimestamp: Date = Date()
    
    init(videoId: String) {
        self.videoId = videoId
        self._currentVideoId = State(initialValue: videoId)
    }
    
    var body: some View {
        ZStack {
            YouTubeWebView(
                videoId: videoId,
                audioPlayer: audioPlayer,
                webView: $webView,
                isReady: $isReady,
                lastCommandSent: $lastCommandSent,
                commandTimestamp: $commandTimestamp
            )
            .onAppear {
                audioPlayer.playbackState = .loading
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SeekToTime"))) { notification in
                if let time = notification.userInfo?["time"] as? TimeInterval,
                   let webView = webView, isReady {
                    webView.evaluateJavaScript("seekTo(\(time));", completionHandler: nil)
                }
            }
            
            if !isReady {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.8))
            }
        }
        .onChange(of: audioPlayer.playbackState) { state in
            handlePlaybackStateChange(state)
        }
        .onChange(of: videoId) { newVideoId in
            print("📺 YouTubePlayerView: Video ID changed from \(currentVideoId) to \(newVideoId)")
            if newVideoId != currentVideoId {
                currentVideoId = newVideoId
                isReady = false
                if let webView = webView {
                    print("📺 Loading new video: \(newVideoId)")
                    webView.evaluateJavaScript("loadNewVideo('\(newVideoId)');", completionHandler: nil)
                } else {
                    print("📺 WebView not ready for video change")
                }
            }
        }
    }
    
    private func handlePlaybackStateChange(_ state: PlaybackState) {
        print("📺 YouTubePlayerView: handlePlaybackStateChange called with state: \(state)")
        print("📺 YouTubePlayerView: webView is \(webView == nil ? "nil" : "available")")
        print("📺 YouTubePlayerView: isReady is \(isReady)")
        
        guard let webView = webView else {
            print("📺 YouTubePlayerView: WebView not available for state change to \(state)")
            // Let's try to wait a bit and retry if webView is nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if self.webView != nil {
                    print("📺 YouTubePlayerView: WebView became available, retrying state change")
                    self.handlePlaybackStateChange(state)
                } else {
                    print("📺 YouTubePlayerView: WebView still not available after delay")
                }
            }
            return
        }
        
        guard isReady else {
            print("📺 YouTubePlayerView: Player not ready for state change to \(state)")
            return
        }
        
        // Prevent sending the same command multiple times rapidly
        let now = Date()
        let timeSinceLastCommand = now.timeIntervalSince(commandTimestamp)
        let commandToSend = "\(state)"
        
        if lastCommandSent == commandToSend && timeSinceLastCommand < 0.5 {
            print("📺 YouTubePlayerView: Skipping duplicate command \(commandToSend), sent \(timeSinceLastCommand)s ago")
            return
        }
        
        lastCommandSent = commandToSend
        commandTimestamp = now
        
        print("📺 YouTubePlayerView: Handling playback state change to \(state)")
        
        switch state {
        case .playing:
            print("📺 YouTubePlayerView: Executing playVideo()")
            webView.evaluateJavaScript("playVideo();") { result, error in
                if let error = error {
                    print("📺 YouTubePlayerView: Error playing video: \(error)")
                } else {
                    print("📺 YouTubePlayerView: Successfully executed playVideo()")
                }
            }
        case .paused:
            print("📺 YouTubePlayerView: Executing pauseVideo()")
            webView.evaluateJavaScript("pauseVideo();") { result, error in
                if let error = error {
                    print("📺 YouTubePlayerView: Error pausing video: \(error)")
                } else {
                    print("📺 YouTubePlayerView: Successfully executed pauseVideo()")
                }
            }
        case .stopped:
            print("📺 YouTubePlayerView: Executing stopVideo()")
            webView.evaluateJavaScript("stopVideo();") { result, error in
                if let error = error {
                    print("📺 YouTubePlayerView: Error stopping video: \(error)")
                } else {
                    print("📺 YouTubePlayerView: Successfully executed stopVideo()")
                }
            }
        case .loading:
            print("📺 YouTubePlayerView: Loading state - will auto-play after delay")
            // When a new track is loaded, we want to auto-play it
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.audioPlayer.playbackState == .loading {
                    print("📺 YouTubePlayerView: Auto-playing after loading delay")
                    webView.evaluateJavaScript("playVideo();") { result, error in
                        if let error = error {
                            print("📺 YouTubePlayerView: Error auto-playing video: \(error)")
                        }
                    }
                }
            }
        default:
            print("📺 YouTubePlayerView: Unhandled playback state: \(state)")
        }
    }
}

struct YouTubeWebView: UIViewRepresentable {
    let videoId: String
    let audioPlayer: AudioPlayerService
    @Binding var webView: WKWebView?
    @Binding var isReady: Bool
    @Binding var lastCommandSent: String
    @Binding var commandTimestamp: Date
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        
        // Create message handler for JavaScript communication
        webView.configuration.userContentController.add(
            context.coordinator,
            name: "playerStateChanged"
        )
        
        // Important: Set the binding immediately
        DispatchQueue.main.async {
            self.webView = webView
        }
        
        let html = createPlayerHTML()
        webView.loadHTMLString(html, baseURL: nil)
        
        print("📺 YouTubeWebView: Created WebView and set binding")
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Update if needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func createPlayerHTML() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { margin: 0; padding: 0; background: black; }
                #player { width: 100%; height: 100%; }
            </style>
        </head>
        <body>
            <div id="player"></div>
            
            <script>
                var tag = document.createElement('script');
                tag.src = "https://www.youtube.com/iframe_api";
                var firstScriptTag = document.getElementsByTagName('script')[0];
                firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
                
                var player;
                var playerReady = false;
                var currentTime = 0;
                var duration = 0;
                
                function onYouTubeIframeAPIReady() {
                    player = new YT.Player('player', {
                        height: '100%',
                        width: '100%',
                        videoId: '\(videoId)',
                        playerVars: {
                            'autoplay': 1,
                            'controls': 1,
                            'modestbranding': 1,
                            'rel': 0,
                            'showinfo': 0,
                            'fs': 1,
                            'playsinline': 1,
                            'enablejsapi': 1
                        },
                        events: {
                            'onReady': onPlayerReady,
                            'onStateChange': onPlayerStateChange,
                            'onError': onPlayerError
                        }
                    });
                }
                
                function onPlayerReady(event) {
                    playerReady = true;
                    duration = player.getDuration();
                    console.log('📺 YouTube Player ready, duration:', duration);
                    
                    // Load pending video if there is one
                    if (window.pendingVideoId) {
                        console.log('📺 Loading pending video:', window.pendingVideoId);
                        player.loadVideoById(window.pendingVideoId);
                        window.pendingVideoId = null;
                        return; // Don't send ready message yet, wait for the new video to load
                    }
                    
                    window.webkit.messageHandlers.playerStateChanged.postMessage({
                        state: 'ready',
                        duration: duration
                    });
                    
                    // Start time tracking
                    setInterval(updateTime, 1000);
                }
                
                function onPlayerStateChange(event) {
                    var state = '';
                    switch(event.data) {
                        case YT.PlayerState.UNSTARTED:
                            state = 'unstarted';
                            break;
                        case YT.PlayerState.ENDED:
                            state = 'ended';
                            break;
                        case YT.PlayerState.PLAYING:
                            state = 'playing';
                            break;
                        case YT.PlayerState.PAUSED:
                            state = 'paused';
                            break;
                        case YT.PlayerState.BUFFERING:
                            state = 'buffering';
                            break;
                        case YT.PlayerState.CUED:
                            state = 'cued';
                            break;
                    }
                    
                    console.log('📺 YouTube Player state changed to:', state);
                    window.webkit.messageHandlers.playerStateChanged.postMessage({
                        state: state,
                        currentTime: player.getCurrentTime(),
                        duration: player.getDuration()
                    });
                }
                
                function onPlayerError(event) {
                    console.error('📺 YouTube Player error:', event.data);
                    window.webkit.messageHandlers.playerStateChanged.postMessage({
                        state: 'error',
                        error: event.data
                    });
                }
                
                function updateTime() {
                    if (playerReady && player.getPlayerState() === YT.PlayerState.PLAYING) {
                        currentTime = player.getCurrentTime();
                        window.webkit.messageHandlers.playerStateChanged.postMessage({
                            state: 'timeUpdate',
                            currentTime: currentTime,
                            duration: duration
                        });
                    }
                }
                
                function playVideo() {
                    console.log('📺 JavaScript: playVideo() called, playerReady:', playerReady);
                    if (playerReady && player) {
                        try {
                            player.playVideo();
                            console.log('📺 JavaScript: playVideo() executed successfully');
                        } catch (error) {
                            console.error('📺 JavaScript: Error in playVideo():', error);
                        }
                    } else {
                        console.warn('📺 JavaScript: Cannot play - player not ready or not available');
                    }
                }
                
                function pauseVideo() {
                    console.log('📺 JavaScript: pauseVideo() called, playerReady:', playerReady);
                    if (playerReady && player) {
                        try {
                            player.pauseVideo();
                            console.log('📺 JavaScript: pauseVideo() executed successfully');
                        } catch (error) {
                            console.error('📺 JavaScript: Error in pauseVideo():', error);
                        }
                    } else {
                        console.warn('📺 JavaScript: Cannot pause - player not ready or not available');
                    }
                }
                
                function stopVideo() {
                    if (playerReady) {
                        player.stopVideo();
                    }
                }
                
                function seekTo(seconds) {
                    if (playerReady) {
                        player.seekTo(seconds, true);
                    }
                }
                
                function setVolume(volume) {
                    if (playerReady) {
                        player.setVolume(volume * 100);
                    }
                }
                
                function loadNewVideo(videoId) {
                    console.log('📺 Loading new video:', videoId);
                    if (playerReady) {
                        player.loadVideoById(videoId);
                    } else {
                        console.log('📺 Player not ready, waiting...');
                        // If player not ready, store the video ID and load when ready
                        window.pendingVideoId = videoId;
                    }
                }
            </script>
        </body>
        </html>
        """
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: YouTubeWebView
        
        init(_ parent: YouTubeWebView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "playerStateChanged",
                  let body = message.body as? [String: Any],
                  let state = body["state"] as? String else { return }
            
            DispatchQueue.main.async {
                self.handlePlayerStateChange(state: state, data: body)
            }
        }
        
        private func handlePlayerStateChange(state: String, data: [String: Any]) {
            let audioPlayer = parent.audioPlayer
            print("📺 YouTube Player state change: \(state)")
            
            // Check if this state change is a response to a recent command we sent
            let now = Date()
            let timeSinceLastCommand = now.timeIntervalSince(parent.commandTimestamp)
            let expectedStateFromCommand = getExpectedStateFromCommand(parent.lastCommandSent)
            let isRecentCommandResponse = timeSinceLastCommand < 2.0 && state == expectedStateFromCommand
            
            print("📺 Time since last command: \(timeSinceLastCommand)s")
            print("📺 Last command sent: '\(parent.lastCommandSent)', expected state: '\(expectedStateFromCommand)'")
            print("📺 Is recent command response: \(isRecentCommandResponse)")
            
            switch state {
            case "ready":
                parent.isReady = true
                if let duration = data["duration"] as? Double {
                    audioPlayer.duration = duration
                    print("📺 Duration set to: \(duration)")
                }
                audioPlayer.updateNowPlayingInfo()
                
            case "playing":
                print("📺 YouTube player is now playing")
                // Always update to keep in sync, but log if it was from our command
                if isRecentCommandResponse {
                    print("📺 ✅ This 'playing' state is response to our command - updating AudioPlayerService")
                } else {
                    print("📺 🎮 This 'playing' state is from user clicking YouTube controls - updating AudioPlayerService")
                }
                audioPlayer.playbackState = .playing
                audioPlayer.updateNowPlayingInfo()
                
            case "paused":
                print("📺 YouTube player is now paused")
                // Always update to keep in sync, but log if it was from our command
                if isRecentCommandResponse {
                    print("📺 ✅ This 'paused' state is response to our command - updating AudioPlayerService")
                } else {
                    print("📺 🎮 This 'paused' state is from user clicking YouTube controls - updating AudioPlayerService")
                }
                audioPlayer.playbackState = .paused
                audioPlayer.updateNowPlayingInfo()
                
            case "ended":
                print("📺 YouTube player ended, playing next track")
                audioPlayer.playNext()
                
            case "buffering":
                print("📺 YouTube player is buffering")
                audioPlayer.playbackState = .buffering
                
            case "error":
                if let errorCode = data["error"] as? Int {
                    let errorMessage = getErrorMessage(errorCode)
                    print("📺 YouTube player error: \(errorMessage) (code: \(errorCode))")
                    audioPlayer.playbackState = .error(errorMessage)
                }
                
            case "timeUpdate":
                if let currentTime = data["currentTime"] as? Double {
                    audioPlayer.currentTime = currentTime
                }
                if let duration = data["duration"] as? Double {
                    audioPlayer.duration = duration
                }
                audioPlayer.updateNowPlayingInfo()
                
            default:
                break
            }
        }
        
        private func getExpectedStateFromCommand(_ command: String) -> String {
            switch command {
            case "playing":
                return "playing"
            case "paused":
                return "paused"
            case "stopped":
                return "paused" // YouTube doesn't have stopped, it pauses
            case "loading":
                return "playing" // Loading usually leads to playing
            default:
                return ""
            }
        }
        
        private func getErrorMessage(_ errorCode: Int) -> String {
            switch errorCode {
            case 2:
                return "Invalid video ID"
            case 5:
                return "HTML5 player error"
            case 100:
                return "Video not found"
            case 101, 150:
                return "Video not available"
            default:
                return "Playback error"
            }
        }
    }
}

import SwiftUI
import AVFoundation
import Combine

struct DeezerSearchResponse: Codable {
    let data: [DeezerTrack]
    let total: Int?
}

struct DeezerTrack: Codable, Identifiable {
    let id: Int
    let title: String
    let preview: String
    let artist: DeezerArtist
    let album: DeezerAlbum
}

struct DeezerArtist: Codable {
    let name: String
}

struct DeezerAlbum: Codable {
    let cover_xl: String
}

enum SwipeDirection {
    case left, right
}

class MusicService: ObservableObject {
    @Published var songs: [DeezerTrack] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentQuery = ""
    private var currentOffset = 0
    
    func searchSongs(query: String = "pop", reset: Bool = true) async {
        if reset {
            currentOffset = 0
            currentQuery = query
            DispatchQueue.main.async {
                self.songs = []
            }
        }
        
        isLoading = true
        errorMessage = nil
        
        let urlString = "https://api.deezer.com/search?q=\(query)&limit=100&index=\(currentOffset)"
        guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(DeezerSearchResponse.self, from: data)
            DispatchQueue.main.async {
                self.songs.append(contentsOf: response.data)
                self.currentOffset += 100
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to load songs: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func loadMore() async {
        guard !isLoading else { return }
        
        if currentQuery == "smart_feed" {
            await loadSmartFeed()
        } else if !currentQuery.isEmpty {
            await searchSongs(query: currentQuery, reset: false)
        }
    }
    
    func loadInfiniteDiscovery() async {
        isLoading = true
        errorMessage = nil
        
        let genres = ["pop", "rock", "hip hop", "electronic", "jazz", "r&b", "indie", "rap", "metal", "country", "reggae", "soul", "funk", "techno", "house", "blues", "classical", "dance", "latin", "folk", "punk", "alternative", "ambient", "disco", "dubstep"]
        
        await withTaskGroup(of: [DeezerTrack].self) { group in
            for genre in genres.shuffled() {
                group.addTask {
                    let urlString = "https://api.deezer.com/search?q=\(genre)&limit=50"
                    guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
                        return []
                    }
                    
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        let response = try JSONDecoder().decode(DeezerSearchResponse.self, from: data)
                        return response.data
                    } catch {
                        return []
                    }
                }
            }
            
            var allSongs: [DeezerTrack] = []
            for await songs in group {
                allSongs.append(contentsOf: songs)
            }
            
            DispatchQueue.main.async {
                var uniqueIds = Set<Int>()
                var uniqueSongs: [DeezerTrack] = []
                for song in allSongs {
                    if !uniqueIds.contains(song.id) {
                        uniqueIds.insert(song.id)
                        uniqueSongs.append(song)
                    }
                }
                self.songs = uniqueSongs.shuffled()
                self.currentQuery = "discovery"
                self.isLoading = false
            }
        }
    }
    
    func loadChartToppers() async {
        isLoading = true
        errorMessage = nil
        
        let urlString = "https://api.deezer.com/chart/0/tracks?limit=500"
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(DeezerSearchResponse.self, from: data)
            DispatchQueue.main.async {
                self.songs = response.data
                self.currentQuery = "charts"
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to load charts: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func loadRecommendations() async {
        isLoading = true
        errorMessage = nil
        
        let likedSongs = LikedSongsManager.shared.likedSongs
        let excludeIds = Set(songs.map { $0.id })
        
        let recommendations = await RecommendationEngine.shared.getRecommendations(
            from: likedSongs,
            excludeIds: excludeIds
        )
        
        DispatchQueue.main.async {
            if recommendations.isEmpty {
                self.errorMessage = "Like some songs first to get recommendations!"
            } else {
                self.songs = recommendations
                self.currentQuery = "recommendations"
            }
            self.isLoading = false
        }
    }
    
    func loadSmartFeed() async {
        isLoading = true
        errorMessage = nil
        
        let likedCount = LikedSongsManager.shared.likedSongs.count
        
        let (discoveryRatio, personalizedRatio): (Double, Double)
        
        switch likedCount {
        case 0...2:
            discoveryRatio = 1.0
            personalizedRatio = 0.0
        case 3...9:
            discoveryRatio = 0.5
            personalizedRatio = 0.5
        default:
            discoveryRatio = 0.2
            personalizedRatio = 0.8
        }
        
        var allSongs: [DeezerTrack] = []
        
        await withTaskGroup(of: [DeezerTrack].self) { group in
            // Discovery songs
            if discoveryRatio > 0 {
                group.addTask {
                    await self.fetchDiscoverySongs(count: Int(100 * discoveryRatio))
                }
            }
            
            if personalizedRatio > 0 && likedCount >= 3 {
                group.addTask {
                    await self.fetchPersonalizedSongs(count: Int(100 * personalizedRatio))
                }
            }
            
            for await songs in group {
                allSongs.append(contentsOf: songs)
            }
        }
        
        DispatchQueue.main.async {
            var uniqueIds = Set<Int>()
            var uniqueSongs: [DeezerTrack] = []
            for song in allSongs.shuffled() {
                if !uniqueIds.contains(song.id) {
                    uniqueIds.insert(song.id)
                    uniqueSongs.append(song)
                }
            }
            
            self.songs = uniqueSongs
            self.currentQuery = "smart_feed"
            self.isLoading = false
        }
    }
    
    private func fetchDiscoverySongs(count: Int) async -> [DeezerTrack] {
        let genres = ["pop", "rock", "hip hop", "electronic", "jazz", "r&b", "indie", "rap", "metal", "country", "reggae", "soul", "funk", "techno", "house", "blues", "dance", "latin", "folk", "alternative"]
        
        var songs: [DeezerTrack] = []
        
        await withTaskGroup(of: [DeezerTrack].self) { group in
            let genresToFetch = min(count / 20, genres.count)
            
            for genre in genres.shuffled().prefix(genresToFetch) {
                group.addTask {
                    let urlString = "https://api.deezer.com/search?q=\(genre)&limit=25"
                    guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
                        return []
                    }
                    
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        let response = try JSONDecoder().decode(DeezerSearchResponse.self, from: data)
                        return response.data
                    } catch {
                        return []
                    }
                }
            }
            
            for await genreSongs in group {
                songs.append(contentsOf: genreSongs)
            }
        }
        
        return songs
    }
    
    private func fetchPersonalizedSongs(count: Int) async -> [DeezerTrack] {
        let likedSongs = LikedSongsManager.shared.likedSongs
        let excludeIds = Set(songs.map { $0.id })
        
        let recommendations = await RecommendationEngine.shared.getRecommendations(
            from: likedSongs,
            excludeIds: excludeIds
        )
        
        return Array(recommendations.prefix(count))
    }
}

class AudioPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var currentSongId: Int?
    
    private var player: AVPlayer?
    
    func play(song: DeezerTrack) {
        guard let url = URL(string: song.preview) else { return }
        
        if currentSongId == song.id && player != nil {
            player?.play()
            isPlaying = true
        } else {
            player = AVPlayer(url: url)
            player?.play()
            isPlaying = true
            currentSongId = song.id
        }
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
        currentSongId = nil
    }
}

struct MusicView: View {
    @StateObject private var musicService = MusicService()
    @StateObject private var audioPlayer = AudioPlayer()
    @ObservedObject private var likedSongsManager = LikedSongsManager.shared
    @State private var passedSongs: [DeezerTrack] = []
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color.cyan.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Song count indicator
                if !musicService.songs.isEmpty {
                    HStack(spacing: 4) {
                        if musicService.isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("loading more...")
                        }
                        
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
                
                if musicService.isLoading && musicService.songs.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading songs...")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else if let error = musicService.errorMessage {
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Retry") {
                            Task {
                                await musicService.loadChartToppers()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                    }
                    .padding()
                    Spacer()
                } else if musicService.songs.isEmpty {
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "music.note")
                            .font(.system(size: 50))
                            .foregroundColor(.cyan)
                        
                        Text("Discover Music")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Swipe to find songs you love!")
                            .foregroundColor(.secondary)
                        
                        Button("Start Swiping") {
                            Task { await musicService.loadSmartFeed() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                    }
                    Spacer()
                } else {
                    VStack {
                
                        ZStack {
                            ForEach(Array(musicService.songs.prefix(3).enumerated()), id: \.element.id) { index, song in
                                SwipeCardView(
                                    song: song,
                                    isPlaying: audioPlayer.isPlaying && audioPlayer.currentSongId == song.id,
                                    onPlayPause: {
                                        if audioPlayer.isPlaying && audioPlayer.currentSongId == song.id {
                                            audioPlayer.pause()
                                        } else {
                                            audioPlayer.play(song: song)
                                        }
                                    },
                                    onRemove: { direction in
                                        withAnimation {
                                            removeSong(direction: direction)
                                        }
                                    }
                                )
                                .zIndex(Double(musicService.songs.count - index))
                                .offset(y: CGFloat(index * 4))
                                .scaleEffect(1 - CGFloat(index) * 0.03)
                                .opacity(index == 0 ? 1 : 0.7)
                                .allowsHitTesting(index == 0)
                                .onAppear {
                                    if index == 0 {
                                        audioPlayer.play(song: song)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .task {
            await musicService.loadSmartFeed()
        }
    }
    
    func removeSong(direction: SwipeDirection) {
        guard !musicService.songs.isEmpty else { return }
        
        audioPlayer.stop()
        
        let song = musicService.songs.removeFirst()
        
        switch direction {
        case .left:
            passedSongs.append(song)
        case .right:
            likedSongsManager.addLikedSong(song)
        }
        
        if !musicService.songs.isEmpty {
            let nextSong = musicService.songs.first!
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.audioPlayer.play(song: nextSong)
            }
        }
        
        if musicService.songs.count < 10 {
            Task {
                await musicService.loadMore()
            }
        }
    }
}

struct SwipeCardView: View {
    let song: DeezerTrack
    let isPlaying: Bool
    let onPlayPause: () -> Void
    let onRemove: (SwipeDirection) -> Void
    
    @State private var offset = CGSize.zero
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 20) {
                Spacer()
                
                ZStack {
                    AsyncImage(url: URL(string: song.album.cover_xl)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 280, height: 280)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 280, height: 280)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                        case .failure:
                            Image(systemName: "music.note")
                                .font(.system(size: 100))
                                .foregroundColor(.gray)
                                .frame(width: 280, height: 280)
                                .background(Color.gray.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        @unknown default:
                            EmptyView()
                        }
                    }
                    
                    HStack {
                        Text("PASS")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.red)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red, lineWidth: 4)
                                    .padding(-10)
                            )
                            .opacity(offset.width < -50 ? Double(-offset.width / 100) : 0)
                            .rotationEffect(.degrees(-20))
                            .padding(.leading, 20)
                        
                        Spacer()

                        Text("LIKE")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.green)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.green, lineWidth: 4)
                                    .padding(-10)
                            )
                            .opacity(offset.width > 50 ? Double(offset.width / 100) : 0)
                            .rotationEffect(.degrees(20))
                            .padding(.trailing, 20)
                    }
                    .frame(width: 280)
                }
                
                VStack(spacing: 8) {
                    Text(song.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal)
                    
                    Text(song.artist.name)
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                HStack(spacing: 30) {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            onRemove(.left)
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.2))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.red)
                        }
                    }
                
                    Button(action: onPlayPause) {
                        ZStack {
                            Circle()
                                .fill(Color.cyan.opacity(0.2))
                                .frame(width: 70, height: 70)
                            
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.cyan)
                        }
                    }
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            onRemove(.right)
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.2))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "heart.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(.top, 10)
                
                HStack(spacing: 8) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 14))
                    Text("Swipe left to pass, right to like")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding(.top, 8)
                
                Spacer()
                
                Text("Powered by Deezer")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 20)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 5)
            )
            .padding(.horizontal, 8)
            .offset(x: offset.width, y: offset.height * 0.4)
            .rotationEffect(.degrees(Double(offset.width / 20)))
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        offset = gesture.translation
                        isDragging = true
                    }
                    .onEnded { gesture in
                        isDragging = false
                        
                        let swipeThreshold: CGFloat = 100
                        
                        if abs(offset.width) > swipeThreshold {
                            // Determine direction and remove
                            let direction: SwipeDirection = offset.width > 0 ? .right : .left
                            
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                offset = CGSize(
                                    width: offset.width > 0 ? 500 : -500,
                                    height: offset.height
                                )
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onRemove(direction)
                                offset = .zero
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                offset = .zero
                            }
                        }
                    }
            )
        }
    }
}

#Preview {
    MusicView()
}

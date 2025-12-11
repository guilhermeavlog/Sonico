import SwiftUI
import Combine

class LikedSongsManager: ObservableObject {
    static let shared = LikedSongsManager()
    
    @Published var likedSongs: [SavedTrack] = []
    
    private let userDefaultsKey = "likedSongs"
    
    private init() {
        loadLikedSongs()
    }
    
    func addLikedSong(_ song: DeezerTrack) {
        guard !likedSongs.contains(where: { $0.id == song.id }) else { return }
        
        let savedTrack = SavedTrack(from: song)
        likedSongs.insert(savedTrack, at: 0)
        saveLikedSongs()
    }
    
    func removeLikedSong(_ song: SavedTrack) {
        likedSongs.removeAll { $0.id == song.id }
        saveLikedSongs()
    }
    
    func isLiked(_ song: DeezerTrack) -> Bool {
        likedSongs.contains { $0.id == song.id }
    }
    
    private func saveLikedSongs() {
        if let encoded = try? JSONEncoder().encode(likedSongs) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    private func loadLikedSongs() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([SavedTrack].self, from: data) {
            likedSongs = decoded
        }
    }
}

struct SavedTrack: Codable, Identifiable {
    let id: Int
    let title: String
    let preview: String
    let artistName: String
    let coverUrl: String
    
    init(from deezerTrack: DeezerTrack) {
        self.id = deezerTrack.id
        self.title = deezerTrack.title
        self.preview = deezerTrack.preview
        self.artistName = deezerTrack.artist.name
        self.coverUrl = deezerTrack.album.cover_xl
    }
}

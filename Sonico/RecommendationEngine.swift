import Foundation

class RecommendationEngine {
    static let shared = RecommendationEngine()
    
    private init() {}

    func getRecommendations(from likedSongs: [SavedTrack], excludeIds: Set<Int>) async -> [DeezerTrack] {
        guard !likedSongs.isEmpty else { return [] }
 
        let topArtists = getTopArtists(from: likedSongs)
        var recommendations: [DeezerTrack] = []
   
        await withTaskGroup(of: [DeezerTrack].self) { group in
            for artist in topArtists.prefix(5) {
                group.addTask {
                    await self.fetchSongsFromArtist(artist: artist)
                }
            }
      
            let genres = self.inferGenres(from: likedSongs)
            for genre in genres.prefix(3) {
                group.addTask {
                    await self.fetchSongsByGenre(genre: genre)
                }
            }
            
            for await songs in group {
                recommendations.append(contentsOf: songs)
            }
        }
      
        var uniqueRecommendations: [DeezerTrack] = []
        var seenIds = excludeIds
        
        for song in recommendations.shuffled() {
            if !seenIds.contains(song.id) {
                uniqueRecommendations.append(song)
                seenIds.insert(song.id)
            
                if uniqueRecommendations.count >= 100 {
                    break
                }
            }
        }
        
        return uniqueRecommendations
    }
    
    private func getTopArtists(from songs: [SavedTrack]) -> [String] {
        let artistCounts = songs.reduce(into: [String: Int]()) { counts, song in
            counts[song.artistName, default: 0] += 1
        }
        
        return artistCounts
            .sorted { $0.value > $1.value }
            .map { $0.key }
    }
    
    private func inferGenres(from songs: [SavedTrack]) -> [String] {
        let genreKeywords = [
            "pop": ["pop", "mainstream"],
            "rock": ["rock", "metal", "punk", "alternative"],
            "hip hop": ["hip hop", "rap", "trap"],
            "electronic": ["electronic", "edm", "house", "techno", "dubstep"],
            "r&b": ["r&b", "soul", "rnb"],
            "indie": ["indie", "alternative"],
            "jazz": ["jazz", "blues"],
            "latin": ["latin", "reggaeton", "salsa"],
            "country": ["country"],
            "classical": ["classical", "orchestra"]
        ]
        
        var genreScores: [String: Int] = [:]
        
        for song in songs {
            let text = "\(song.title) \(song.artistName)".lowercased()
            
            for (genre, keywords) in genreKeywords {
                for keyword in keywords {
                    if text.contains(keyword) {
                        genreScores[genre, default: 0] += 1
                    }
                }
            }
        }
        
        if genreScores.isEmpty {
            return ["pop", "rock", "hip hop", "electronic"]
        }
        
        return genreScores
            .sorted { $0.value > $1.value }
            .map { $0.key }
    }
    
    private func fetchSongsFromArtist(artist: String) async -> [DeezerTrack] {
        let urlString = "https://api.deezer.com/search?q=artist:\"\(artist)\"&limit=30"
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
    
    private func fetchSongsByGenre(genre: String) async -> [DeezerTrack] {
        let urlString = "https://api.deezer.com/search?q=\(genre)&limit=30"
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

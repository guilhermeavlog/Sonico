import SwiftUI

struct GenresView: View {
    @ObservedObject private var likedSongsManager = LikedSongsManager.shared
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color.cyan.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if likedSongsManager.likedSongs.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 60))
                        .foregroundColor(.cyan.opacity(0.5))
                    
                    Text("No Stats Yet")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Start liking songs to see your\nmusic taste insights")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your Stats")
                                    .font(.title.bold())
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        
                        HStack(spacing: 12) {
                            StatCard(
                                icon: "heart.fill",
                                title: "Liked Songs",
                                value: "\(likedSongsManager.likedSongs.count)",
                                color: .red
                            )
                            
                            StatCard(
                                icon: "person.wave.2",
                                title: "Artists",
                                value: "\(uniqueArtistsCount)",
                                color: .blue
                            )
                        }
                        .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Top Artists")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                ForEach(Array(topArtists.prefix(5).enumerated()), id: \.offset) { index, artist in
                                    ArtistRowView(
                                        rank: index + 1,
                                        artistName: artist.name,
                                        songCount: artist.count
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Vibe")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Text("Based on your liked songs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(inferredGenres, id: \.self) { genre in
                                        GenreChip(genre: genre)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recently Liked")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                ForEach(likedSongsManager.likedSongs.prefix(5)) { song in
                                    RecentSongRow(song: song)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    var uniqueArtistsCount: Int {
        Set(likedSongsManager.likedSongs.map { $0.artistName }).count
    }
    
    var topArtists: [(name: String, count: Int)] {
        let artistCounts = likedSongsManager.likedSongs.reduce(into: [String: Int]()) { counts, song in
            counts[song.artistName, default: 0] += 1
        }
        
        return artistCounts
            .sorted { $0.value > $1.value }
            .map { (name: $0.key, count: $0.value) }
    }
    
    var inferredGenres: [String] {
        let genreKeywords: [String: [String]] = [
            "Pop": ["pop", "mainstream"],
            "Rock": ["rock", "metal", "punk"],
            "Hip Hop": ["hip hop", "rap", "trap"],
            "Electronic": ["electronic", "edm", "house", "techno", "dubstep"],
            "R&B": ["r&b", "soul", "rnb"],
            "Indie": ["indie", "alternative"],
            "Jazz": ["jazz", "blues"],
            "Latin": ["latin", "reggaeton", "salsa"],
            "Country": ["country"],
            "Classical": ["classical", "orchestra"]
        ]
        
        var genreScores: [String: Int] = [:]
        
        for song in likedSongsManager.likedSongs {
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
            return ["Pop", "Rock", "Hip Hop"]
        }
        
        return genreScores
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(color)
            
            Text(value)
                .font(.title.bold())
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct ArtistRowView: View {
    let rank: Int
    let artistName: String
    let songCount: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Text("\(rank)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(rankColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(artistName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text("\(songCount) song\(songCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .cyan
        }
    }
}

struct GenreChip: View {
    let genre: String
    
    var body: some View {
        Text(genre)
            .font(.subheadline.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [.cyan, .blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(20)
            .shadow(color: .cyan.opacity(0.3), radius: 5, x: 0, y: 3)
    }
}

struct RecentSongRow: View {
    let song: SavedTrack
    
    var body: some View {
        HStack(spacing: 12) {
            // Album artwork
            AsyncImage(url: URL(string: song.coverUrl)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 50, height: 50)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure:
                    Image(systemName: "music.note")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                        .frame(width: 50, height: 50)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                @unknown default:
                    EmptyView()
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(song.artistName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "heart.fill")
                .font(.system(size: 16))
                .foregroundColor(.red)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    GenresView()
}

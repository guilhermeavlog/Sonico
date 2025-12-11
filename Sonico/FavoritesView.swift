import SwiftUI
import AVFoundation
import Combine

class FavoritesAudioPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var currentSongId: Int?
    
    private var player: AVPlayer?
    
    func play(song: SavedTrack) {
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

struct FavoritesView: View {
    @ObservedObject private var likedSongsManager = LikedSongsManager.shared
    @StateObject private var audioPlayer = FavoritesAudioPlayer()
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
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
                    Image(systemName: "heart.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.cyan.opacity(0.5))
                    
                    Text("No Favorites Yet")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Swipe right on songs you like\nand they'll appear here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your Favorites")
                                .font(.title.bold())
                            Text("\(likedSongsManager.likedSongs.count) songs")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(likedSongsManager.likedSongs) { song in
                                FavoriteSongCard(
                                    song: song,
                                    isPlaying: audioPlayer.isPlaying && audioPlayer.currentSongId == song.id,
                                    onPlayPause: {
                                        if audioPlayer.isPlaying && audioPlayer.currentSongId == song.id {
                                            audioPlayer.pause()
                                        } else {
                                            audioPlayer.play(song: song)
                                        }
                                    },
                                    onRemove: {
                                        withAnimation {
                                            likedSongsManager.removeLikedSong(song)
                                        }
                                        if audioPlayer.currentSongId == song.id {
                                            audioPlayer.stop()
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }
}

struct FavoriteSongCard: View {
    let song: SavedTrack
    let isPlaying: Bool
    let onPlayPause: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Album artwork
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: song.coverUrl)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(height: 180)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .clipped()
                    case .failure:
                        Image(systemName: "music.note")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                            .frame(height: 180)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.2))
                    @unknown default:
                        EmptyView()
                    }
                }
                
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18))
                        .foregroundColor(.red)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.7))
                        )
                }
                .padding(8)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(song.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(song.artistName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Button(action: onPlayPause) {
                    HStack {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 20))
                        Text(isPlaying ? "Playing" : "Preview")
                            .font(.caption.bold())
                    }
                    .foregroundColor(.cyan)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.cyan.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.top, 4)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    FavoritesView()
}

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("SONICO")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(.cyan)
                    .tracking(2)
                
                Text("Songs a swipe away")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .tracking(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            .padding(.bottom, 10)
            
            Group {
                switch selectedTab {
                case 0:
                    FavoritesView()
                case 1:
                    MusicView()
                case 2:
                    GenresView()
                default:
                    FavoritesView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            BottomNavigationBar(selectedTab: $selectedTab)
        }
    }
}

struct BottomNavigationBar: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack(spacing: 0) {
            NavBarButton(
                icon: "star.fill",
                isSelected: selectedTab == 0,
                action: { selectedTab = 0 }
            )
            
            NavBarButton(
                icon: "music.note",
                isSelected: selectedTab == 1,
                action: { selectedTab = 1 }
            )
            
            NavBarButton(
                icon: "person.fill",
                isSelected: selectedTab == 2,
                action: { selectedTab = 2 }
            )
        }
        .padding(.vertical, 12)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: -5)
        )
    }
}

struct NavBarButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .light))
                .foregroundColor(isSelected ? .cyan : .secondary)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    ContentView()
}

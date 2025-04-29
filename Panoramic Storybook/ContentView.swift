import SwiftUI

struct ContentView: View {
    var body: some View {
        PageCurlViewController()
            .edgesIgnoringSafeArea(.all)
    }
}

struct PageCurlViewController: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> StoryPageViewController {
        return StoryPageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal,
            options: nil
        )
    }
    func updateUIViewController(_ uiViewController: StoryPageViewController, context: Context) { }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif

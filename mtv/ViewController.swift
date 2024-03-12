import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let playlistScreenViewController = PlayListViewController()
        addChild(playlistScreenViewController)
        playlistScreenViewController.view.frame = view.bounds
        view.addSubview(playlistScreenViewController.view)
        playlistScreenViewController.didMove(toParent: self)
    }
}


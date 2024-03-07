import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let artistScreenViewController = PlayListViewController()
        addChild(artistScreenViewController)
        artistScreenViewController.view.frame = view.bounds
        view.addSubview(artistScreenViewController.view)
        artistScreenViewController.didMove(toParent: self)
    }
}


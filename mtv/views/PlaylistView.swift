//
//  PlaylistView.swift
//  mtv
//
//  Created by Ali Humza on 08/03/2024.
//

import Foundation
import UIKit

class PlaylistListView: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var playlists: [Playlist] = []
    var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView = UITableView(frame: view.bounds, style: .plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        view.addSubview(tableView)

        fetchPlaylists(apiKey: apiKey, baseURLString:  "https://api.airtable.com/v0/appxCBIOkiJEZiph7/MTvPlaylists") { result in
            switch result {
            case .success(let fetchedPlaylists):
                DispatchQueue.main.async {
                    self.playlists = fetchedPlaylists
                    self.tableView.reloadData()
                }
            case .failure(let error):
                print("Error fetching playlists: \(error)")
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playlists.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let playlist = playlists[indexPath.row]
        cell.textLabel?.text = "\(playlist.fields.videoTitles?.count)"
        return cell
    }
}

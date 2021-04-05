//
//  HistoryView.swift
//  TikTokTrainer
//
//  Created by Hunter Jarrell on 3/2/21.
//

import SwiftUI

struct HistoryView: View {

    @Environment(\.managedObjectContext) var managedObjectContext
    @FetchRequest(
        entity: StoredResult.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \StoredResult.timestamp, ascending: false)
        ]
    ) var results: FetchedResults<StoredResult>
    @State var editMode = EditMode.inactive
    @State var selection = Set<StoredResult>()

    func setBackground() {
        UITableView.appearance().backgroundColor = UIColor.white
        UITableViewCell.appearance().selectedBackgroundView = {
                    let view = UIView()
                    view.backgroundColor = .white
                    return view
                }()
    }

    var background: some View {
        Rectangle()
            .fill()
            .ignoresSafeArea(.all)
            .background(Color.white)
            .foregroundColor(Color.white)
    }

    var deleteButton: some View {
        if editMode == .inactive {
            return Button(action: {}) {
                Image(systemName: "")
            }
        } else {
            return Button(action: deleteResults) {
                Image(systemName: "trash")
            }
        }
    }

    var selectButton: some View {
        if editMode == .inactive {
            return Button(action: {
                self.editMode = .active
                self.selection = Set<StoredResult>()
            }) {
                Text("Select")
                    .foregroundColor(Color.black)
            }
        } else {
            return Button(action: {
                self.editMode = .inactive
                self.selection = Set<StoredResult>()
            }) {
                Text("Cancel")
                    .foregroundColor(Color.black)
            }
        }
    }

    private func deleteResults() {
        self.editMode = .inactive
        for result in selection {
            managedObjectContext.delete(result)
        }
        DataController.shared.save()
        selection = Set<StoredResult>()
    }

    var body: some View {
        ZStack {
            background
            VStack {
                HStack {
                    if results.count > 0 {
                        deleteButton
                            .padding(.leading, 20)
                    }
                    Spacer()
                    if results.count > 0 {
                        selectButton
                            .padding(.trailing, 10)
                    }
                }
                Text("History")
                    .font(.largeTitle)
                    .foregroundColor(Color.black)
                if results.count > 0 {
                    List(selection: $selection) {
                        ForEach(results, id: \.self) { (result: StoredResult) in
                            ResultRow(result: result)
                        }.listRowBackground(Color.white)
                    }
                    .onAppear(perform: setBackground)
                    .environment(\.editMode, self.$editMode)
                } else {
                    Spacer()
                    Text("No results found.")
                        .bold()
                    Spacer()
                }
            }
            .background(Color.white)
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}

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
    @State var selectionSet = Set<StoredResult>()
    @State var isHistoryDetailViewOpen = false
    @State var selection = 0

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
                self.selectionSet = Set<StoredResult>()
            }) {
                Text("Select")
                    .foregroundColor(Color.black)
            }
        } else {
            return Button(action: {
                self.editMode = .inactive
                self.selectionSet = Set<StoredResult>()
            }) {
                Text("Cancel")
                    .foregroundColor(Color.black)
            }
        }
    }

    private func deleteResults() {
        self.editMode = .inactive
        for result in selectionSet {
            managedObjectContext.delete(result)
        }
        DataController.shared.save()
        selectionSet = Set<StoredResult>()
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
                    List(selection: $selectionSet) {
                        ForEach(results, id: \.self) { (result: StoredResult) in
                            ResultRow(result: result)
                                .onTapGesture {
                                    if editMode == .inactive {
                                        selection = results.firstIndex(of: result)!
                                        isHistoryDetailViewOpen = true
                                    }
                                }
                        }
                        .listRowBackground(Color.white)
                    }
                    .fullScreenCover(isPresented: $isHistoryDetailViewOpen) {
                        HistoryDetailView(result: results[selection])
                            .ignoresSafeArea(.all, edges: .all)
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

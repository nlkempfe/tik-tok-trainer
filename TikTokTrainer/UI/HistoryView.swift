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
            NSSortDescriptor(keyPath: \StoredResult.timestamp, ascending: true)
        ]
    ) var results: FetchedResults<StoredResult>
    @State var editMode = EditMode.inactive
    @State var selection = Set<StoredResult>()

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
                    deleteButton
                        .padding(.leading, 20)
                    Spacer()
                    selectButton
                        .padding(.trailing, 10)
                }
                Text("Results")
                    .font(.largeTitle)
                List(selection: $selection) {
                    ForEach(results, id: \.self) { (result: StoredResult) in
                        ResultRow(result: result)
                    }
                }
                .environment(\.editMode, self.$editMode)
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

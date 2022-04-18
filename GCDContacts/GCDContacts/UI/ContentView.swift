//
//  ContentView.swift
//  GCDContacts
//
//  Created by Alfred Lapkovsky on 13/04/2022.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject private var viewModel = ContentViewModel()
    @State private var isAddContactModeActive = false
    
    private var navigationTitle = "Contacts"
    
    var body: some View {
        NavigationView {
            if !viewModel.contacts.isEmpty {
                buildLoadedContent()
            } else if viewModel.isLoading {
                buildProgressContent()
            } else {
                buildInitialContent()
            }
        }
        .onAppear {
            viewModel.load()
        }
    }
    
    private func buildLoadedContent() -> some View {
        VStack {
            List {
                ForEach(viewModel.contacts) { contact in
                    NavigationLink {
                        ContactDetailsView(viewModel: ContactViewModel.shared(for: contact))
                    } label: {
                        ContactItemView(contact)
                    }
                }
            }
            
            NavigationLink(isActive: $isAddContactModeActive) {
                AddContactView()
            } label: {
                EmptyView()
            }
            .hidden()
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem {
                buildContextMenu()
            }
        }
    }
    
    private func buildProgressContent() -> some View {
        ProgressView()
            .scaleEffect(2)
            .navigationTitle(navigationTitle)
    }
    
    private func buildInitialContent() -> some View {
        VStack {
            Spacer()
            
            Image(systemName: "person.3")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 80, alignment: .center)
                .foregroundColor(.gray)
            
            Text("No contacts found.")
                .font(Font.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(Color.black.opacity(0.6))
            
            Spacer()
            
            buildActionButton(text: "Add new", imageName: "person.crop.circle.fill.badge.plus") {
                isAddContactModeActive = true
            }
            .background(Color.blue)
            .foregroundColor(Color.white)
            .cornerRadius(8)
            
            buildActionButton(text: "Import contacts", imageName: "arrow.up.and.person.rectangle.portrait") {
                viewModel.importContacts()
            }
            buildActionButton(text: "Generate contacts", imageName: "person.crop.rectangle.stack") {
                viewModel.generateContacts()
            }
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 48, trailing: 0))
            
        }
        .padding()
        .padding(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .buttonStyle(BorderedButtonStyle())
        .navigationTitle(navigationTitle)
    }
    
    private func buildContextMenu() -> some View {
        Menu {
            buildContextMenuButton("Add new", icon: "person.crop.circle.fill.badge.plus") {
                isAddContactModeActive = true
            }
            buildContextMenuButton("Import contacts", icon: "arrow.up.and.person.rectangle.portrait") {
                viewModel.importContacts()
            }
            buildContextMenuButton("Generate contacts", icon: "person.crop.rectangle.stack") {
                viewModel.generateContacts()
            }

            Divider()
            
            Menu {
                buildContextMenuButton("Auto", icon: viewModel.sortType == .auto ? "checkmark" : nil) {
                    viewModel.updateSortType(.auto)
                }
                buildContextMenuButton("First name", icon: viewModel.sortType == .firstName ? "checkmark" : nil) {
                    viewModel.updateSortType(.firstName)
                }
                buildContextMenuButton("Last name", icon: viewModel.sortType == .lastName ? "checkmark" : nil) {
                    viewModel.updateSortType(.lastName)
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down.circle")
                Text("Sort")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
    
    private func buildContextMenuButton(_ title: String, icon: String? = nil, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            if let icon = icon {
                Image(systemName: icon)
            }
            Text(title)
        }
    }
    
    private func buildActionButton(text: String, imageName: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Image(systemName: imageName)
            Text(text)
                .font(Font.system(size: 16, weight: .semibold, design: .default))
                .frame(maxWidth: Double.infinity, alignment: .center)
                .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        }
    }
    
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

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
                        Menu {
                            Button {
                                isAddContactModeActive = true
                            } label: {
                                Image(systemName: "person.crop.circle.fill.badge.plus")
                                Text("Add new")
                            }
                            Button {
                                viewModel.importContacts()
                            } label: {
                                Image(systemName: "arrow.up.and.person.rectangle.portrait")
                                Text("Import contacts")
                            }
                            Button {
                                viewModel.generateContacts()
                            } label: {
                                Image(systemName: "person.crop.rectangle.stack")
                                Text("Generate contacts")
                            }
                            Divider()
                            Menu {
                                Button {
                                    viewModel.updateSortType(.auto)
                                } label: {
                                    if viewModel.sortType == .auto {
                                        Image(systemName: "checkmark")
                                    }
                                    Text("Auto")
                                }
                                Button {
                                    viewModel.updateSortType(.firstName)
                                } label: {
                                    if viewModel.sortType == .firstName {
                                        Image(systemName: "checkmark")
                                    }
                                    Text("First name")
                                }
                                Button {
                                    viewModel.updateSortType(.lastName)
                                } label: {
                                    if viewModel.sortType == .lastName {
                                        Image(systemName: "checkmark")
                                    }
                                    Text("Last name")
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down.circle")
                                Text("Sort")
                            }

                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            } else if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(2)
                    .navigationTitle(navigationTitle)
            } else {
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
                    actionButton(text: "Add new", imageName: "person.crop.circle.fill.badge.plus") {
                        isAddContactModeActive = true
                    }
                    .background(Color.blue)
                    .foregroundColor(Color.white)
                    .cornerRadius(8)
                    actionButton(text: "Import contacts", imageName: "arrow.up.and.person.rectangle.portrait") {
                        viewModel.importContacts()
                    }
                    actionButton(text: "Generate contacts", imageName: "person.crop.rectangle.stack") {
                        viewModel.generateContacts()
                    }
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 48, trailing: 0))
                    
                }
                .padding()
                .padding(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .buttonStyle(BorderedButtonStyle())
                .navigationTitle(navigationTitle)
            }
        }
        .onAppear {
            viewModel.load()
        }
    }
    
    private func actionButton(text: String, imageName: String, action: @escaping () -> Void) -> some View {
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

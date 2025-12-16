//
//  SearchablePicker.swift
//  owlitiOS
//
//  Created by Sushant Bhat on 16/12/2025.
//

import SwiftUI

struct SearchablePicker: View {
    let title: String
    let placeholder: String
    @Binding var selection: String
    let options: [String]
    var allowCreate: Bool = true
    var displayIcon: (String) -> AnyView = { _ in AnyView(EmptyView()) } // Optional icon provider
    var onSelect: ((String) -> Void)? = nil
    var onCreate: ((String) -> Void)? = nil

    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var isPresentingSheet = false
    
    // Custom colors - Dark Mode
    let cardBg = Color(hex: "111111")
    let textWhite = Color.white
    let textGray = Color.gray
    let accentGreen = Color(hex: "27A565")
    let sheetBg = Color.black // Pitch black for sheet

    var filteredOptions: [String] {
        if searchText.isEmpty {
            return options
        } else {
            return options.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var showCreateOption: Bool {
        allowCreate && !searchText.isEmpty && !options.contains { $0.localizedCaseInsensitiveCompare(searchText) == .orderedSame }
    }

    var body: some View {
        Button(action: {
            isPresentingSheet = true
        }) {
            HStack {
                displayIcon(selection).font(.system(size: 14))
                
                Text(selection.isEmpty ? placeholder : selection)
                    .font(.custom("FKGroteskTrial-Regular", size: 14))
                    .foregroundColor(selection.isEmpty ? textWhite.opacity(0.3) : textWhite)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(textWhite.opacity(0.5))
            }
            .contentShape(Rectangle()) // Make clickable area better
        }
        .sheet(isPresented: $isPresentingSheet) {
            NavigationView {
                ZStack {
                    sheetBg.ignoresSafeArea()
                    
                    List {
                        if showCreateOption {
                            Button(action: {
                                let newValue = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                                selection = newValue
                                onCreate?(newValue)
                                onSelect?(newValue)
                                isPresentingSheet = false
                                searchText = ""
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(accentGreen)
                                    Text("Create \"\(searchText)\"")
                                        .font(.custom("FKGroteskTrial-Medium", size: 16))
                                        .foregroundColor(textWhite)
                                }
                            }
                            .listRowBackground(cardBg)
                        }
                        
                        ForEach(filteredOptions, id: \.self) { option in
                            Button(action: {
                                selection = option
                                onSelect?(option)
                                isPresentingSheet = false
                            }) {
                                HStack {
                                    displayIcon(option)
                                        .foregroundColor(textWhite.opacity(0.7))
                                        .frame(width: 24)
                                    
                                    Text(option)
                                        .font(.custom("FKGroteskTrial-Regular", size: 16))
                                        .foregroundColor(textWhite)
                                    
                                    if selection == option {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .foregroundColor(accentGreen)
                                    }
                                }
                            }
                            .listRowBackground(cardBg)
                        }
                        
                        if filteredOptions.isEmpty && !showCreateOption {
                           Text("No options found")
                               .foregroundColor(textGray)
                               .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden) // Important for custom bg
                    .background(sheetBg)
                }
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search \(title.lowercased())...")
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isPresentingSheet = false
                        }
                        .foregroundColor(textWhite)
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .preferredColorScheme(.dark)
        }
    }
}

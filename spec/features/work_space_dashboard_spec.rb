require 'rails_helper'
require 'shared_examples/volunteer_control_panel'

RSpec.feature 'work space dashboard', type: :feature, js: true do
  highlight_by_warp = 'Highlight target district by WARP'
  highlight_by_estimates = 'Highlight target district by estimates'

  def create_visible_committee_room
    work_space = create(:work_space)
    create(
      :committee_room,
      work_space: work_space,
      polling_districts: [
        create(
          :polling_district,
          ward: create(:ward, work_space: work_space),
          # Create with a polling station associated so shows up on dashboard.
          polling_stations: [create(:polling_station)]
        )
      ]
    )
  end

  def expect_suggested_target_district_to_be(district_reference)
    row = find_district_row(district_reference)
    expect(row[:class]).to include('suggested-target-district')
  end

  def expect_suggested_target_district_not_to_be(district_reference)
    row = find_district_row(district_reference)
    expect(row[:class]).not_to include('suggested-target-district')
  end

  def find_district_row(district_reference)
    find_data_test(
      "polling-district-row-#{district_reference}"
    )
  end

  it 'displays all polling stations, with key stats' do
    polling_station = create(
      :polling_station,
      name: 'Some Polling Station',
      reference: 'SPS-123',
      polling_district: create(
        :polling_district,
        reference: 'PD',
        ward: create(:ward, name: 'My Ward'),
        box_electors: 200,
        box_labour_promises: 100,
        postal_labour_promises: 20,
        postal_electors: 60
      )
    )

    visit work_space_path(polling_station.work_space)

    expect(page).to have_text('Some Polling Station')
    expect(page).to have_text('MY WARD | PD | SPS-123')
    expect(page).to have_text('100 promises / 200 box voters')
    expect(page).to have_text('20 promises / 60 postal voters')
    expect(page).to have_text('0 (not yet observed)')
  end

  it 'shows details/stats for latest turnout observation for each polling station' do
    polling_district = create(
      :polling_district,
      box_electors: 200,
      box_labour_promises: 100
    )
    polling_station = create(
      :polling_station, polling_district: polling_district
    )
    create(
      :turnout_observation,
      polling_station: polling_station,
      count: 120,
      created_at: DateTime.new(2019, 12, 12, 11, 23)
    )

    visit work_space_path(polling_station.work_space)

    expect(page).to have_text('120 at 11:23')
    expect(page).to have_text('60.0%')
    expect(page).to have_text('60 votes / 40 votes left')
  end

  it 'shows volunteer that made latest turnout observation, if present' do
    polling_station = create(:polling_station)
    create(
      :turnout_observation,
      polling_station: polling_station,
      count: 120,
      created_at: DateTime.new(2019, 12, 12, 11, 23),
      user: create(:user, name: 'Some Campaigner')
    )

    visit work_space_path(polling_station.work_space)

    expect(page).to have_text(/120 at 11:23.*\nby Some Campaigner/)
  end

  it 'shows sum of valid WARP count observations for each polling district' do
    polling_district = create(
      :polling_district,
      box_electors: 200,
      box_labour_promises: 100
    )
    # Needed so shows up on dashboard.
    create(
      :polling_station,
      polling_district: polling_district
    )
    create(
      :warp_count_observation,
      count: 20,
      polling_district: polling_district
    )
    create(
      :warp_count_observation,
      count: 40,
      polling_district: polling_district
    )
    create(
      :warp_count_observation,
      count: 10,
      is_valid: false,
      polling_district: polling_district
    )

    visit work_space_path(polling_district.work_space)

    expect(page).to have_text('60 votes / 40 votes left')
  end

  it 'shows total of all valid WARP counts for work space' do
    work_space = create(:work_space)
    3.times do
      create(
        :warp_count_observation,
        count: 20,
        polling_district: create(
          :polling_district,
          ward: create(:ward, work_space: work_space)
        )
      )
    end
    create(
      :warp_count_observation,
      count: 10,
      is_valid: false,
      polling_district: create(
        :polling_district,
        ward: create(:ward, work_space: work_space)
      )
    )

    visit work_space_path(work_space)

    expect(page).to have_text('Total: 60')
  end

  it 'highlights highest priority district for committee room, with toggleable method' do
    committee_room = create(:committee_room)
    work_space = committee_room.work_space
    _lowest_warp_count_polling_station = create(
      :polling_station,
      polling_district: create(
        :polling_district,
        reference: 'PD1',
        box_electors: 100,
        box_labour_promises: 50,
        warp_count_observations: [create(:warp_count_observation, count: 20)],
        ward: create(:ward, work_space: work_space),
        committee_room: committee_room
      ),
      turnout_observations: [create(:turnout_observation, count: 60)]
    )
    _most_estimated_votes_left_polling_station = create(
      :polling_station,
      polling_district: create(
        :polling_district,
        reference: 'PD2',
        box_electors: 100,
        box_labour_promises: 50,
        warp_count_observations: [create(:warp_count_observation, count: 40)],
        ward: create(:ward, work_space: work_space),
        committee_room: committee_room
      ),
      # Need to have at least 1 turnout observation for turnout estimate
      # highlighting to consider this district.
      turnout_observations: [create(:turnout_observation, count: 30)]
    )

    visit work_space_path(work_space)

    click_on highlight_by_warp
    expect_suggested_target_district_to_be('PD1')
    expect_suggested_target_district_not_to_be('PD2')
    expect(page).to have_no_button(highlight_by_warp)

    click_on highlight_by_estimates
    expect_suggested_target_district_to_be('PD2')
    expect_suggested_target_district_not_to_be('PD1')
    expect(page).to have_no_button(highlight_by_estimates)
  end

  it 'highlights nothing when no observations yet' do
    committee_room = create(:committee_room)
    work_space = committee_room.work_space
    polling_district = create(
      :polling_district,
      reference: 'PD',
      box_electors: 100,
      box_labour_promises: 50,
      ward: create(:ward, work_space: work_space)
    )
    create(
      :polling_station,
      polling_district: polling_district,
      committee_room: committee_room
    )

    visit work_space_path(work_space)
    click_on highlight_by_warp
    expect_suggested_target_district_not_to_be('PD')

    visit work_space_path(work_space)
    click_on highlight_by_estimates
    expect_suggested_target_district_not_to_be('PD')
  end

  describe 'remaining lifts tracking' do
    include_examples 'volunteer_control_panel'

    subject do
      create(:polling_district, polling_stations: [create(:polling_station)])
    end

    let :count_element do
      find_data_test("remaining-lifts-#{subject.id}")
    end

    let(:observations_method) { :remaining_lifts_observations }
  end

  describe 'canvassers tracking' do
    include_examples 'volunteer_control_panel'

    subject { create_visible_committee_room }

    let :count_element do
      find_data_test("canvassers-#{subject.id}")
    end

    let(:observations_method) { :canvassers_observations }
  end

  describe 'cars tracking' do
    include_examples 'volunteer_control_panel'

    subject { create_visible_committee_room }

    let :count_element do
      find_data_test("cars-#{subject.id}")
    end

    let(:observations_method) { :cars_observations }
  end
end

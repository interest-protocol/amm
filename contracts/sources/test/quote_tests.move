#[test_only]
module amm::quote_tests {
  use std::option;

  use sui::object;
  use sui::clock::{Self, Clock};
  use sui::test_utils::assert_eq;
  use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
  
  use suitears::math64;

  use amm::quote;
  use amm::utils;
  use amm::stable;
  use amm::volatile;
  use amm::eth::ETH;
  use amm::usdc::USDC;
  use amm::usdt::USDT;
  use amm::fees::{Self, Fees};
  use amm::curves::{Volatile, Stable};
  use amm::ipx_v_eth_usdc::IPX_V_ETH_USDC;
  use amm::ipx_s_usdc_usdt::IPX_S_USDC_USDT;
  use amm::interest_protocol_amm::{Self, Registry, InterestPool};
  use amm::deploy_utils::{people, scenario, deploy_eth_usdc_pool, deploy_usdc_usdt_pool};

  const USDC_DECIMAL_SCALAR: u64 = 1_000_000;
  const ETH_DECIMAL_SCALAR: u64 = 1_000_000_000;
  const USDT_DECIMAL_SCALAR: u64 = 1_000_000_000;

  #[test]
  fun test_volatile_quote_amount_out() {
    let scenario = scenario();
    let (alice, _) = people();

    let scenario_mut = &mut scenario;

    set_up_test(scenario_mut);
    deploy_eth_usdc_pool(scenario_mut, 15 * ETH_DECIMAL_SCALAR, 37500 * USDC_DECIMAL_SCALAR);

    next_tx(scenario_mut, alice);
    {
      let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

      let amount_in = 3 * ETH_DECIMAL_SCALAR;
      let amount_in_fee = fees::get_fee_in_amount(&request.pool_fees, amount_in);
      let expected_amount_out = volatile::get_amount_out(amount_in - amount_in_fee, 15 * ETH_DECIMAL_SCALAR, 37500 * USDC_DECIMAL_SCALAR);
      let expected_amount_out = expected_amount_out - fees::get_fee_out_amount(&request.pool_fees, expected_amount_out); 

      assert_eq(quote::amount_out<ETH, USDC, IPX_V_ETH_USDC>(&request.pool, &request.clock, amount_in), expected_amount_out);

      destroy_request(request);
    };

    next_tx(scenario_mut, alice);
    {
      let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

      let amount_in = 14637 * USDC_DECIMAL_SCALAR;
      let amount_in_fee = fees::get_fee_in_amount(&request.pool_fees, amount_in);
      let expected_amount_out = volatile::get_amount_out(amount_in - amount_in_fee, 37500 * USDC_DECIMAL_SCALAR, 15 * ETH_DECIMAL_SCALAR);
      let expected_amount_out = expected_amount_out - fees::get_fee_out_amount(&request.pool_fees, expected_amount_out); 

      assert_eq(quote::amount_out<USDC, ETH, IPX_V_ETH_USDC>(&request.pool, &request.clock, amount_in), expected_amount_out);

      destroy_request(request);
    };
    test::end(scenario);    
  }

  #[test]
  fun test_stable_quote_amount_out() {
    let scenario = scenario();
    let (alice, _) = people();

    let scenario_mut = &mut scenario;

    set_up_test(scenario_mut);
    deploy_usdc_usdt_pool(scenario_mut, 25000 * USDC_DECIMAL_SCALAR, 25000 * USDT_DECIMAL_SCALAR);    

    next_tx(scenario_mut, alice);
    {
      let request = request<Stable, USDC, USDT, IPX_S_USDC_USDT>(scenario_mut);

      let amount_in = 599 * USDC_DECIMAL_SCALAR;
      let amount_in_fee = fees::get_fee_in_amount(&request.pool_fees, amount_in);
      let expected_amount_out = stable::get_amount_out(
        amount_in - amount_in_fee, 
        25000 * USDC_DECIMAL_SCALAR, 
        25000 * USDT_DECIMAL_SCALAR,
        USDC_DECIMAL_SCALAR,
        USDT_DECIMAL_SCALAR,
        true
      );
      let expected_amount_out = expected_amount_out - fees::get_fee_out_amount(&request.pool_fees, expected_amount_out); 

      assert_eq(quote::amount_out<USDC, USDT, IPX_S_USDC_USDT>(&request.pool, &request.clock, amount_in), expected_amount_out);

      destroy_request(request);
    };

    next_tx(scenario_mut, alice);
    {
      let request = request<Stable, USDC, USDT, IPX_S_USDC_USDT>(scenario_mut);

      let amount_in = 763 * USDT_DECIMAL_SCALAR;
      let amount_in_fee = fees::get_fee_in_amount(&request.pool_fees, amount_in);
      let expected_amount_out = stable::get_amount_out(
        amount_in - amount_in_fee, 
        25000 * USDC_DECIMAL_SCALAR, 
        25000 * USDT_DECIMAL_SCALAR,
        USDC_DECIMAL_SCALAR,
        USDT_DECIMAL_SCALAR,
        false
      );
      let expected_amount_out = expected_amount_out - fees::get_fee_out_amount(&request.pool_fees, expected_amount_out); 

      assert_eq(quote::amount_out<USDT, USDC, IPX_S_USDC_USDT>(&request.pool, &request.clock, amount_in), expected_amount_out);

      destroy_request(request);
    };

    test::end(scenario);
  }

  #[test]
  fun test_volatile_quote_amount_in() {
    let scenario = scenario();
    let (alice, _) = people();

    let scenario_mut = &mut scenario;

    set_up_test(scenario_mut);
    deploy_eth_usdc_pool(scenario_mut, 15 * ETH_DECIMAL_SCALAR, 37500 * USDC_DECIMAL_SCALAR);

    next_tx(scenario_mut, alice);
    {   
      let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

      let amount_out = 6 * ETH_DECIMAL_SCALAR;
      let amount_out_before_fee = fees::get_fee_out_initial_amount(&request.pool_fees, amount_out);

      let expected_amount_in = fees::get_fee_in_initial_amount(
        &request.pool_fees, 
        volatile::get_amount_in(amount_out_before_fee, 15 * ETH_DECIMAL_SCALAR, 37500 * USDC_DECIMAL_SCALAR)
      );

      assert_eq(quote::amount_in<ETH, USDC, IPX_V_ETH_USDC>(&request.pool, &request.clock, amount_out), expected_amount_in);

      destroy_request(request);
    };

    next_tx(scenario_mut, alice);
    {
      let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);     

      let amount_out = 2999 * USDC_DECIMAL_SCALAR;
      let amount_out_before_fee = fees::get_fee_out_initial_amount(&request.pool_fees, amount_out);

      let expected_amount_in = fees::get_fee_in_initial_amount(
        &request.pool_fees, 
        volatile::get_amount_in(amount_out_before_fee, 37500 * USDC_DECIMAL_SCALAR, 15 * ETH_DECIMAL_SCALAR)
      );

      assert_eq(quote::amount_in<USDC, ETH, IPX_V_ETH_USDC>(&request.pool, &request.clock, amount_out), expected_amount_in);

      destroy_request(request);
    };

    test::end(scenario);
  }

  #[test]
  fun test_stable_quote_amount_in() {
    let scenario = scenario();
    let (alice, _) = people();

    let scenario_mut = &mut scenario;

    set_up_test(scenario_mut);
    deploy_usdc_usdt_pool(scenario_mut, 25000 * USDC_DECIMAL_SCALAR, 25000 * USDT_DECIMAL_SCALAR); 
    
    next_tx(scenario_mut, alice);
    {
      let request = request<Stable, USDC, USDT, IPX_S_USDC_USDT>(scenario_mut);

      let amount_out = 2999 * USDC_DECIMAL_SCALAR;
      let amount_out_before_fee = fees::get_fee_out_initial_amount(&request.pool_fees, amount_out);

      let expected_amount_in = fees::get_fee_in_initial_amount(
        &request.pool_fees, 
        stable::get_amount_in(
          amount_out_before_fee,
          25000 * USDC_DECIMAL_SCALAR, 
          25000 * USDT_DECIMAL_SCALAR,
          USDC_DECIMAL_SCALAR,
          USDT_DECIMAL_SCALAR,
          true          
        )
      );

      assert_eq(quote::amount_in<USDC, USDT, IPX_S_USDC_USDT>(&request.pool, &request.clock, amount_out), expected_amount_in);

      destroy_request(request);   
    };

    next_tx(scenario_mut, alice);
    {      
      let request = request<Stable, USDC, USDT, IPX_S_USDC_USDT>(scenario_mut);

      let amount_out = 2999 * USDT_DECIMAL_SCALAR;
      let amount_out_before_fee = fees::get_fee_out_initial_amount(&request.pool_fees, amount_out);

      let expected_amount_in = fees::get_fee_in_initial_amount(
        &request.pool_fees, 
        stable::get_amount_in(
          amount_out_before_fee,
          25000 * USDC_DECIMAL_SCALAR, 
          25000 * USDT_DECIMAL_SCALAR,
          USDC_DECIMAL_SCALAR,
          USDT_DECIMAL_SCALAR,
          false          
        )
      );

      assert_eq(quote::amount_in<USDT, USDC, IPX_S_USDC_USDT>(&request.pool, &request.clock, amount_out), expected_amount_in);

      destroy_request(request);     
    };

    test::end(scenario);
  }

  #[test]
  fun test_quote_add_liquidity() {
    let scenario = scenario();
    let (alice, _) = people();

    let scenario_mut = &mut scenario;

    set_up_test(scenario_mut);
    deploy_eth_usdc_pool(scenario_mut, 15 * ETH_DECIMAL_SCALAR, 37500 * USDC_DECIMAL_SCALAR);

    next_tx(scenario_mut, alice);
    {
      let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

      let balance_x = interest_protocol_amm::balance_x<ETH, USDC, IPX_V_ETH_USDC>(&request.pool);
      let balance_y = interest_protocol_amm::balance_y<ETH, USDC, IPX_V_ETH_USDC>(&request.pool);
      let lp_coin_supply = interest_protocol_amm::lp_coin_supply<ETH, USDC, IPX_V_ETH_USDC>(&request.pool);

      let eth_amount = 3 * ETH_DECIMAL_SCALAR;
      let usdc_amount = 15000 * USDC_DECIMAL_SCALAR;
      
      let (shares, optimal_x_amount, optimal_y_amount) = quote::add_liquidity<ETH, USDC, IPX_V_ETH_USDC>(&request.pool, 3 * ETH_DECIMAL_SCALAR, 15000 * USDC_DECIMAL_SCALAR);

      let (expected_x_amount, expected_y_amount) = utils::get_optimal_add_liquidity(eth_amount, usdc_amount, balance_x, balance_y);

      assert_eq(expected_x_amount, optimal_x_amount);
      assert_eq(expected_y_amount, optimal_y_amount);
      assert_eq(math64::min(
        math64::mul_div_down(optimal_x_amount, lp_coin_supply, balance_x),
        math64::mul_div_down(optimal_y_amount, lp_coin_supply, balance_y),
      ), shares);

      destroy_request(request);  
    };
    test::end(scenario);
  }

  #[test]
  fun test_remove_liquidity() {
    let scenario = scenario();
    let (alice, _) = people();

    let scenario_mut = &mut scenario;

    set_up_test(scenario_mut);
    deploy_eth_usdc_pool(scenario_mut, 15 * ETH_DECIMAL_SCALAR, 37500 * USDC_DECIMAL_SCALAR);

    next_tx(scenario_mut, alice);
    {
      let request = request<Volatile, ETH, USDC, IPX_V_ETH_USDC>(scenario_mut);

      let balance_x = interest_protocol_amm::balance_x<ETH, USDC, IPX_V_ETH_USDC>(&request.pool);
      let balance_y = interest_protocol_amm::balance_y<ETH, USDC, IPX_V_ETH_USDC>(&request.pool);
      let lp_coin_supply = interest_protocol_amm::lp_coin_supply<ETH, USDC, IPX_V_ETH_USDC>(&request.pool);

      let amount = lp_coin_supply / 3;

      let expected_eth_amount = math64::mul_div_down(amount, balance_x, lp_coin_supply);
      let expected_usdc_amount = math64::mul_div_down(amount, balance_y, lp_coin_supply);

      let (eth_amount, usdc_amount, fee_eth, fee_usdc) = quote::remove_liquidity<ETH, USDC, IPX_V_ETH_USDC>(&request.pool, &request.clock, amount);

      assert_eq(eth_amount, expected_eth_amount);
      assert_eq(usdc_amount, expected_usdc_amount);
      assert_eq(fee_eth, 0);
      assert_eq(fee_usdc, 0);

      destroy_request(request);  
    };
    test::end(scenario);
  }

  // Set up

  struct Request {
    registry: Registry,
    pool: InterestPool,
    pool_fees: Fees,
    clock: Clock
  }

  fun set_up_test(scenario_mut: &mut Scenario) {
    let (alice, _) = people();

    next_tx(scenario_mut, alice);
    {
      interest_protocol_amm::init_for_testing(ctx(scenario_mut));
    };
  }

  fun request<Curve, CoinX, CoinY, LPCoinType>(scenario_mut: &mut Scenario): Request {
    let registry = test::take_shared<Registry>(scenario_mut);
    let pool_address = interest_protocol_amm::pool_address<Curve, CoinX, CoinY>(&registry);
    let pool = test::take_shared_by_id<InterestPool>(
      scenario_mut, object::id_from_address(option::destroy_some(pool_address))
    );
    let pool_fees = interest_protocol_amm::fees<CoinX, CoinY, LPCoinType>(&pool);
    let clock = clock::create_for_testing(ctx(scenario_mut));

    Request {
      registry,
      pool,
      pool_fees,
      clock
    }
  }

  fun destroy_request(request: Request) {
    let Request { registry, pool, clock, pool_fees: _ } = request;

    clock::destroy_for_testing(clock);

    test::return_shared(registry);
    test::return_shared(pool); 
  }
}
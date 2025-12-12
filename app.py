from flask import Flask, request, jsonify, send_from_directory
import requests
import os
import polyline
import time

app = Flask(__name__, static_folder='.', static_url_path='')

@app.route('/')
def index():
    return send_from_directory('.', 'index.html')

@app.route('/geocode')
def geocode():
    address = request.args.get('address', '').strip()
    if not address:
        return jsonify({'error': 'address is required'}), 400

    url = 'https://nominatim.openstreetmap.org/search'
    params = {
        'q': address,
        'format': 'json',
        'limit': 1
    }
    headers = {
        'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36'
    }

    try:
        resp = requests.get(url, params=params, headers=headers, timeout=5)
        resp.raise_for_status()
        results = resp.json()

        if not results:
            return jsonify({'error': 'not_found'}), 404

        lat = float(results[0]['lat'])
        lon = float(results[0]['lon'])
        return jsonify({'lat': lat, 'lon': lon})
    except Exception as e:
        print('Geocode error:', e)
        return jsonify({'error': 'geocode_failed'}), 500

@app.route('/route')
def route():
    """
    /route?start_lat=..&start_lon=..&end_lat=..&end_lon=..
    Возвращает список координат маршрута в формате:
    { "coordinates": [[lat, lon], [lat, lon], ...] }
    """
    try:
        start_lat = float(request.args.get('start_lat'))
        start_lon = float(request.args.get('start_lon'))
        end_lat = float(request.args.get('end_lat'))
        end_lon = float(request.args.get('end_lon'))
    except (TypeError, ValueError):
        return jsonify({'error': 'invalid_coordinates'}), 400

    # OSRM demo-сервер (пешеходный/автомобильный маршрут — возьмём driving)
    osrm_url = (
        f"https://router.project-osrm.org/route/v1/driving/"
        f"{start_lon},{start_lat};{end_lon},{end_lat}"
    )
    params = {
        "overview": "full",
        "geometries": "geojson"  # получаем coords в формате [lon, lat]
    }

    try:
        r = requests.get(osrm_url, params=params, timeout=5)
        r.raise_for_status()
        data = r.json()

        if not data.get("routes"):
            return jsonify({'error': 'no_route'}), 404

        geometry = data["routes"][0]["geometry"]
        # geometry: { "coordinates": [[lon, lat], ...], "type": "LineString" }

        coords_lonlat = geometry["coordinates"]
        # Leaflet ждёт [lat, lon], поэтому меняем местами
        coords_latlon = [[lat, lon] for lon, lat in coords_lonlat]

        return jsonify({'coordinates': coords_latlon})
    except Exception as e:
        print("Route error:", e)
        return jsonify({'error': 'route_failed'}), 500
    
@app.route('/suggest')
def suggest():
    """
    /suggest?q=...
    Возвращает список подсказок адресов:
    [
      {"label": "ul. ...", "lat": 52.23, "lon": 21.01},
      ...
    ]
    """
    query = request.args.get('q', '').strip()
    if not query or len(query) < 3:
        return jsonify([])

    url = 'https://nominatim.openstreetmap.org/search'
    params = {
        'q': query,
        'format': 'json',
        'limit': 5,
        'addressdetails': 1
    }
    headers = {
        # ОБЯЗАТЕЛЬНО укажи свой контакт, чтобы не банили
        'User-Agent': 'accessible-rides-demo/1.0 (your-email@example.com)'
    }

    try:
        resp = requests.get(url, params=params, headers=headers, timeout=5)
        resp.raise_for_status()
        results = resp.json()

        suggestions = []
        for item in results:
            suggestions.append({
                'label': item.get('display_name'),
                'lat': float(item['lat']),
                'lon': float(item['lon'])
            })

        return jsonify(suggestions)
    except Exception as e:
        print('Suggest error:', e)
        return jsonify([]), 500

@app.route('/process-payment', methods=['POST'])
def process_payment():
    """
    Эмуляция обработки платежа
    В реальном приложении здесь будет интеграция с платежной системой
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'success': False, 'error': 'No data received'}), 400
            
        # Проверяем обязательные поля
        required_fields = ['cardNumber', 'cardExpiry', 'cardCVC', 'cardName', 'email', 'amount', 'booking']
        for field in required_fields:
            if field not in data:
                return jsonify({'success': False, 'error': f'Missing field: {field}'}), 400
        
        # Проверяем данные бронирования
        booking = data.get('booking', {})
        if not booking.get('startISO') or not booking.get('endISO'):
            return jsonify({'success': False, 'error': 'Invalid booking data'}), 400
        
        # Проверяем тестовые данные карты
        card_number = data.get('cardNumber', '')
        if card_number != '4242424242424242':
            return jsonify({'success': False, 'error': 'Invalid card number. Use test card: 4242 4242 4242 4242'}), 400
        
        # Имитация обработки платежа
        time.sleep(2)  # Имитация задержки обработки
        
        # Для демо просто возвращаем успех
        return jsonify({
            'success': True,
            'paymentId': 'pay_' + str(abs(hash(str(data))))[:16],
            'transactionId': 'txn_' + str(abs(hash(str(data))))[:16],
            'message': 'Payment processed successfully'
        })
        
    except Exception as e:
        print('Payment processing error:', e)
        return jsonify({'success': False, 'error': f'Payment processing failed: {str(e)}'}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=True)

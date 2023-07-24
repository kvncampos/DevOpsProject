import React, { Component, MouseEvent } from 'react';


const API_URL = require('./config.json').apiUrl;

interface IKeyValue {
    key: string;
    value: string;
}

class App extends Component<{}, IKeyValue> {
    constructor(props: any) {
        super(props);

        this.state = {
            key: '',
            value: '',
        };

        this.postKv.bind(this);
        this.getKv.bind(this);
    }

    getKv = async (event: MouseEvent) => {
        const state = this.state;
        console.log(state);
        const resp = await fetch(`${API_URL}/${state.key}`, {
            headers: {
                'Content-Type': 'application/json',
            },
        });

        this.setState(await resp.json());
    };

    postKv = async (event: MouseEvent) => {
        const state = this.state;

        await fetch(API_URL, {
            method: 'post',
            body: JSON.stringify(state),
            headers: {
                'Content-Type': 'application/json',
            },
        });

        this.setState({});
    };

    render() {
        const { key, value } = this.state;

        return (
            <div>
                <p>add a key and value</p>
                <div>
                    <label htmlFor="key-input">key: </label>
                    <input type="text" id="key-input" onChange={event => this.setState({ key: event.target.value })} />
                </div>
                <div>
                    <label htmlFor="value-input">value: </label>
                    <input type="text" id="value-input" onChange={event => this.setState({ value: event.target.value })} />
                    <button onClick={this.postKv}>submit</button>
                </div>
                <hr />
                <p>fetch a value</p>
                <div>
                    <label htmlFor="key-input">key: </label>
                    <input type="text" id="key-input" onChange={event => this.setState({ key: event.target.value })} />
                    <button onClick={this.getKv}>submit</button>
                </div>
                <div>
                    <label htmlFor="value-field">value: </label>
                    <strong><span id="value-field"></span>{value}</strong>
                </div>
            </div>
        )
    }
}

export default App;
